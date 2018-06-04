let
  fetchNixpkgs = import ./fetchNixpkgs.nix;

  nixpkgs = fetchNixpkgs {
     rev          = "e02dfb51cfdcebccc2d8cc9b615e27a1440618b6";
     sha256       = "1q8s0r6mv8p0xddairvmcjjln8jgrif5mfpiy8khrblk9sz5hvpa";
     outputSha256 = "153x6wg6b7hywrdc02jfyibwg7277dxrb4sz2acbvpmg1r6bjlvm";
  };

  pkgs = import nixpkgs { config = {}; };

  caffe = import ./.;
in
  with pkgs;

  stdenv.mkDerivation {
    name = "segnet-caffe-env";
    nativeBuildInputs =
      [ caffe
        caffe.py
        python27
      ] ++ (with pythonPackages; [
        cython
        numpy
        scipy
        scikitimage
        matplotlib
        ipython
        h5py
        leveldb
        networkx
        nose
        pandas
        dateutil_1_5
        protobuf3_1
        gflags
        pyyaml
        pillow
        six
        opencv
      ]);
    shellHook = ''
      export NIX_PATH="nixpkgs=${toString nixpkgs}"
    '';
  }
