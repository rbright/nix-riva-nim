{
  description = "NVIDIA Riva NIM runner (Parakeet ASR)";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      flake-utils,
      nixpkgs,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            curl
            deadnix
            docker
            jq
            just
            nixfmt
            prek
            ripgrep
            shellcheck
            statix
          ];
        };

        formatter = pkgs.nixfmt;
      }
    )
    // {
      nixosModules.default =
        {
          config,
          lib,
          ...
        }:
        let
          cfg = config.services.rivaNim;
          serviceName = "docker-${cfg.containerName}";
          runtimeUid = toString cfg.runtimeUid;
          runtimeGid = toString cfg.runtimeGid;
          cacheDirEscaped = lib.escapeShellArg cfg.cacheDir;
          modelsDirEscaped = lib.escapeShellArg cfg.modelsDir;
        in
        {
          options.services.rivaNim = {
            enable = lib.mkEnableOption "Run NVIDIA Riva NIM ASR as a Docker-managed OCI container";

            containerName = lib.mkOption {
              type = lib.types.str;
              default = "riva-nim";
              description = "Container name for the Riva NIM service.";
            };

            image = lib.mkOption {
              type = lib.types.str;
              default = "nvcr.io/nim/nvidia/parakeet-1-1b-ctc-en-us:latest";
              description = "NIM container image (pin by digest once authenticated pull is confirmed).";
            };

            tagsSelector = lib.mkOption {
              type = lib.types.str;
              default = "name=parakeet-1-1b-ctc-en-us,mode=all";
              description = "NIM_TAGS_SELECTOR value.";
            };

            envFile = lib.mkOption {
              type = lib.types.str;
              default = "/etc/riva-nim.env";
              description = "Absolute path to env file containing NGC_API_KEY (path is host-configurable).";
            };

            cacheDir = lib.mkOption {
              type = lib.types.str;
              default = "/var/lib/riva-nim/cache";
              description = "Persistent host cache directory mounted into /opt/nim/.cache.";
            };

            modelsDir = lib.mkOption {
              type = lib.types.str;
              default = "/var/lib/riva-nim/models";
              description = "Persistent host model repository directory mounted into /data/models.";
            };

            runtimeUid = lib.mkOption {
              type = lib.types.int;
              default = 1000;
              description = "UID that should own cache/models directories for container write access.";
            };

            runtimeGid = lib.mkOption {
              type = lib.types.int;
              default = 1000;
              description = "GID that should own cache/models directories for container write access.";
            };

            listenAddress = lib.mkOption {
              type = lib.types.str;
              default = "127.0.0.1";
              description = "Bind address for exposed service ports.";
            };

            grpcPort = lib.mkOption {
              type = lib.types.port;
              default = 50051;
              description = "Host gRPC port binding.";
            };

            httpPort = lib.mkOption {
              type = lib.types.port;
              default = 9000;
              description = "Host HTTP port binding.";
            };

            healthPath = lib.mkOption {
              type = lib.types.str;
              default = "/v1/health/ready";
              description = "HTTP health endpoint path exposed by the NIM service.";
            };

            extraOptions = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "--gpus=all"
                "--shm-size=8g"
                "--ulimit=nofile=2048:2048"
              ];
              description = "Extra docker/OCI runtime options passed to the container.";
            };
          };

          config = lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = lib.strings.hasPrefix "/" cfg.healthPath;
                message = "services.rivaNim.healthPath must start with '/'";
              }
              {
                assertion = lib.strings.hasPrefix "/" cfg.envFile;
                message = "services.rivaNim.envFile must be an absolute path";
              }
              {
                assertion = lib.strings.hasPrefix "/" cfg.cacheDir;
                message = "services.rivaNim.cacheDir must be an absolute path";
              }
              {
                assertion = lib.strings.hasPrefix "/" cfg.modelsDir;
                message = "services.rivaNim.modelsDir must be an absolute path";
              }
            ];

            hardware.nvidia-container-toolkit.enable = true;

            virtualisation = {
              docker = {
                enable = true;
                enableOnBoot = true;
              };
              oci-containers = {
                backend = "docker";
                containers.${cfg.containerName} = {
                  autoStart = true;
                  inherit (cfg) image extraOptions;
                  environment = {
                    NIM_TAGS_SELECTOR = cfg.tagsSelector;
                  };
                  environmentFiles = [ cfg.envFile ];
                  ports = [
                    "${cfg.listenAddress}:${toString cfg.grpcPort}:50051"
                    "${cfg.listenAddress}:${toString cfg.httpPort}:9000"
                  ];
                  volumes = [
                    "${cfg.cacheDir}:/opt/nim/.cache"
                    "${cfg.modelsDir}:/data/models"
                  ];
                };
              };
            };

            systemd.services.${serviceName} = {
              after = [
                "docker.service"
                "network-online.target"
              ];
              wants = [ "network-online.target" ];
              unitConfig.ConditionPathExists = cfg.envFile;
              preStart = lib.mkBefore ''
                install -d -m 0700 -o ${runtimeUid} -g ${runtimeGid} ${cacheDirEscaped}
                install -d -m 0700 -o ${runtimeUid} -g ${runtimeGid} ${modelsDirEscaped}

                cache_owner="$(stat -c '%u:%g' ${cacheDirEscaped})"
                if [ "$cache_owner" != "${runtimeUid}:${runtimeGid}" ]; then
                  chown -R ${runtimeUid}:${runtimeGid} ${cacheDirEscaped}
                fi

                models_owner="$(stat -c '%u:%g' ${modelsDirEscaped})"
                if [ "$models_owner" != "${runtimeUid}:${runtimeGid}" ]; then
                  chown -R ${runtimeUid}:${runtimeGid} ${modelsDirEscaped}
                fi
              '';
            };

            systemd.tmpfiles.rules = [
              "d ${cfg.cacheDir} 0700 ${runtimeUid} ${runtimeGid} -"
              "d ${cfg.modelsDir} 0700 ${runtimeUid} ${runtimeGid} -"
            ];
          };
        };
    };
}
