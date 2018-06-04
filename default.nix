let
  fetchNixpkgs = import ./fetchNixpkgs.nix;

  nixpkgs = fetchNixpkgs {
     rev          = "e02dfb51cfdcebccc2d8cc9b615e27a1440618b6";
     sha256       = "1q8s0r6mv8p0xddairvmcjjln8jgrif5mfpiy8khrblk9sz5hvpa";
     outputSha256 = "153x6wg6b7hywrdc02jfyibwg7277dxrb4sz2acbvpmg1r6bjlvm";
  };

  pkgs = import nixpkgs { config = {}; };

in

with nixpkgs;
with pkgs;
with lib;

let
  protobuf = protobuf3_1;
  cudaSupport = false;
  cudnnSupport = false;
  cudnn = null;
  pythonSupport = true;

  python = python2;
  pythonPackages = python2Packages;
in
stdenv.mkDerivation rec {
  # Use git revision because latest "release" is really old
  name = "caffe-segnet";

  src = ./.;

  enableParallelBuilding = true;

  outputs = ["out" "proto"] ++ lib.optional pythonSupport "py";

  preConfigure = ''
    pythonInclude=${python}/include/${python.libPrefix} \
    numpyInclude=${pythonPackages.numpy}/lib/${python.libPrefix}/site-packages/numpy/core/include \
      substituteAll ${./Makefile.config} Makefile.config
  '';

  makeFlags = "BLAS=open " +
              (if !cudaSupport then "CPU_ONLY=1 " else "CUDA_DIR=${cudatoolkit7} ") +
              (if cudnnSupport then "USE_CUDNN=1 " else "")
              + lib.optionalString enableParallelBuilding "-j";

  # too many issues with tests to run them for now
  doCheck = false;
  checkPhase = "make runtest ${makeFlags}";

  buildInputs = [ hdf5 leveldb lmdb snappy ]
                ++ optional cudaSupport cudatoolkit7
                ++ optional cudnnSupport cudnn
                ++ optionals pythonSupport [ python pythonPackages.numpy ];

  propagatedBuildInputs = [ openblas boost google-gflags glog protobuf opencv ];

  propagatedPythonInputs = with pythonPackages; [
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
  ];

  buildPhase = ''
    echo make $makeFlags
    make $makeFlags
    make $makeFlags pycaffe
  '';

  installPhase = ''
    mkdir -p $out/{bin,share,lib}
    for bin in $(find build/tools -executable -type f -name '*.bin');
    do
      cp $bin $out/bin/$(basename $bin .bin)
    done

    cp -r build/examples $out/share
    cp -r build/lib $out
    cp -r include $out
    mkdir -p $out/include/caffe/proto
    cp build/src/caffe/proto/caffe.pb.h $out/include/caffe/proto/

    mkdir -p "$proto"
    cp src/caffe/proto/caffe.proto "$proto"
  '';

  postFixup = stdenv.lib.optionalString pythonSupport ''
    mkdir -p $py/nix-support
    echo ${pythonPackages.numpy} >> $py/nix-support/propagated-native-build-inputs
    echo ${lib.concatStringsSep " " propagatedPythonInputs} >> $py/nix-support/propagated-native-build-inputs
    pythondir="$py/lib/${python.libPrefix}/site-packages"
    mkdir -p "$pythondir"
    mv python/caffe "$pythondir"
  '';

  meta = with stdenv.lib; {
    description = "Deep learning framework";
    longDescription = ''
      Caffe is a deep learning framework made with expression, speed, and
      modularity in mind. It is developed by the Berkeley Vision and Learning
      Center (BVLC) and by community contributors.
    '';

    maintainers = with maintainers; [ jb55 ];
    license = licenses.bsd2;
    platforms = platforms.linux;
  };
}
