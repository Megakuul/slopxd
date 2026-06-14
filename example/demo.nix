{pkgs ? import <nixpkgs> {}}:
with pkgs;
  stdenv.mkDerivation {
    pname = "demo";
    version = "0.1.0";

    src = fetchFromGitHub {
      owner = "example";
      repo = "demo";
      rev = "v0.1.0";
      hash = "";
    };

    nativeBuildInputs = [pkg-config];
    buildInputs = [zlib];

    installPhase = ''
      runHook preInstall
      install -Dm755 demo $out/bin/demo
      runHook postInstall
    '';

    meta = {
      description = "Demo package for nixmax";
      license = lib.licenses.mit;
      mainProgram = "demo";
    };
  }
