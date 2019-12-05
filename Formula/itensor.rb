class Itensor < Formula
  desc "C++ library for implementing tensor product wavefunction calculations"
  homepage "http://itensor.org/"
  url "https://github.com/ITensor/ITensor/archive/v3.1.1.tar.gz"
  sha256 "3c12d288e50522b5bd152f956a48ec187486cfeb4ccb1ea9a05d3f0bf3bf8059"
  head "https://github.com/ITensor/ITensor.git"

  option "with-openblas", "Build with OpenBLAS"
  option "with-libflame", "Build with libFLAME"

  if build.with? "openblas"
    if build.with? "libflame"
      odie "Options --with-openblas and --with-libflame are mutually exclusive."
    end
    depends_on "openblas"
  elsif build.with? "libflame"
    depends_on "libflame"
    depends_on "blis"
  end

  unless OS.mac?
    fails_with :gcc => "5"
    fails_with :gcc => "6"
  end

  def install
    ENV.cxx11
    if build.with? "openblas"
      platform = "openblas"
      openblas_dir = Formula["openblas"].opt_prefix
      blas_lapack_libflags = "-L#{openblas_dir}/lib -lopenblas -lpthread"
      blas_lapack_includeflags = "-I#{openblas_dir}/include -DHAVE_LAPACK_CONFIG_H -DLAPACK_COMPLEX_STRUCTURE"
    elsif build.with? "libflame"
      platform = "lapack"
      libflame_dir = Formula["libflame"].opt_prefix
      blis_dir = Formula["blis"].opt_prefix
      blas_lapack_libflags = "-L#{libflame_dir}/lib -L#{blis_dir}/lib -lflame -lblis -lpthread"
      blas_lapack_includeflags = "-I#{libflame_dir}/include -I#{blis_dir}/include"
    elsif OS.mac?
      platform="macos"
      blas_lapack_libflags = "-framework Accelerate"
      blas_lapack_includeflags = ""
    else
      platform="lapack"
      blas_lapack_libflags = "-llapack -lblas"
      blas_lapack_includeflags = ""
    end

    (buildpath/"options.mk").write <<~EOS
      CCCOM=#{ENV.cxx} -std=c++17 -fPIC
      PLATFORM=#{platform}
      BLAS_LAPACK_LIBFLAGS=#{blas_lapack_libflags}
      BLAS_LAPACK_INCLUDEFLAGS=#{blas_lapack_includeflags}
      OPTIMIZATIONS=-O2 -DNDEBUG -Wall
      DEBUGFLAGS=-DDEBUG -g -Wall -pedantic
      ITENSOR_MAKE_DYLIB=1
      PREFIX=#{prefix}
      ITENSOR_LIBDIR=#{lib}
      ITENSOR_INCLUDEDIR=#{buildpath}
      ITENSOR_INCLUDEFLAGS=-I$(ITENSOR_INCLUDEDIR) $(BLAS_LAPACK_INCLUDEFLAGS)

      CCFLAGS=-I. $(ITENSOR_INCLUDEFLAGS) $(OPTIMIZATIONS) -Wno-unused-variable
      CCGFLAGS=-I. $(ITENSOR_INCLUDEFLAGS) $(DEBUGFLAGS)

      UNAME_S := $(shell uname -s)
      ifeq ($(UNAME_S),Darwin)
        DYLIB_EXT ?= dylib
        DYLIB_FLAGS ?= -dynamiclib
      else
        DYLIB_EXT ?= so
        DYLIB_FLAGS ?= -shared
      endif
    EOS

    lib.mkpath

    system "make", "-j#{ENV.make_jobs}"

    include.mkpath
    ["itensor",
     "itensor/detail",
     "itensor/mps",
     "itensor/mps/lattice",
     "itensor/mps/sites",
     "itensor/itdata",
     "itensor/tensor",
     "itensor/util"].each do |p|
      (include + p).mkpath
      (include + p).install Dir["#{p}/*.h", "#{p}/*.ih"]
    end
  end

  test do
    if build.with? "openblas"
      openblas_dir = Formula["openblas"].opt_prefix
      blas_lapack_flags = ["-DHAVE_LAPACK_CONFIG_H", "-DLAPACK_COMPLEX_STRUCTURE",
                           "-L#{openblas_dir}/lib", "-lopenblas", "-lpthread"]
    elsif build.with? "libflame"
      libflame_dir = Formula["libflame"].opt_prefix
      blis_dir = Formula["blis"].opt_prefix
      blas_lapack_flags = ["-L#{libflame_dir}/lib", "-L#{blis_dir}/lib", "-lflame", "-lblis", "-lpthread"]
    elsif OS.mac?
      blas_lapack_flags = ["-framework", "Accelerate"]
    else
      blas_lapack_flags = ["-llapack", "-lblas"]
    end

    (testpath/"test.cc").write <<~EOS
      #include "itensor/all.h"
      using namespace itensor;
      int main()
      {
          Index i(2, "i"), j(2);
          ITensor t(i,j), u(i), s, v;
          t.fill(1.0);
          svd(t, u, s, v);
          printfln("%.2f", norm(s));
          return 0;
      }
    EOS
    system ENV.cxx, "-std=c++17", "test.cc", "-o", "test",
                    "-I#{include}", "-L#{lib}", "-litensor", *blas_lapack_flags
    assert_match "2.00", shell_output("./test").chomp
  end
end
