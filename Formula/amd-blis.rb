class AmdBlis < Formula
  desc "BLAS-like Library Instantiation Software Framework"
  homepage "https://developer.amd.com/amd-aocl"
  url "https://github.com/amd/blis/archive/2.0.tar.gz"
  sha256 "7469680ce955f39d8d6bb7f70d2cc854222e5ef92a39488e77421300a65fad83"
  head "https://github.com/amd/blis.git"

  conflicts_with "blis", :because => "this is an AMD fork of the same library"

  def install
    build_flags = ["--enable-cblas"]
    if build.stable?
      build_flags << "--export-shared=all"
    end
    system "./configure", "--prefix=#{prefix}", *build_flags, "auto"
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdio.h>
      #include <stdlib.h>
      #include <math.h>
      #include "blis/blis.h"

      int main(void) {
        int i;
        double A[6] = {1.0, 2.0, 1.0, -3.0, 4.0, -1.0};
        double B[6] = {1.0, 2.0, 1.0, -3.0, 4.0, -1.0};
        double C[9] = {.5, .5, .5, .5, .5, .5, .5, .5, .5};
        cblas_dgemm(CblasColMajor, CblasNoTrans, CblasTrans,
                    3, 3, 2, 1, A, 3, B, 3, 2, C, 3);
        for (i = 0; i < 9; i++)
          printf("%lf ", C[i]);
        printf("\\n");
        if (fabs(C[0]-11) > 1.e-5) abort();
        if (fabs(C[4]-21) > 1.e-5) abort();
        return 0;
      }
    EOS
    system ENV.cc, "-o", "test", "test.c", "-I#{include}", "-L#{lib}", "-lblis", "-lm"
    system "./test"
  end
end
