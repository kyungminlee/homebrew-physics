class Maxent < Formula
  desc "A utility for performing analytic continuation using the method of Maximum Entropy"
  homepage "https://github.com/CQMP/Maxent"
  url "https://github.com/CQMP/Maxent/archive/v1.1.1.tar.gz"
  version "1.1.1"
  sha256 "30778a343507d5cd3ba2e88294141ec4967de6e8cc5ff3442bb9d5f6facdd6ed"

  depends_on "cmake" => :build
  depends_on "boost"
  depends_on "eigen"
  depends_on "gsl"
  depends_on "alpscore"

  def install
    # ENV.deparallelize  # if your formula fails when building in parallel
    args = std_cmake_args
    args.delete "-DCMAKE_BUILD_TYPE=None"
    args << "-DCMAKE_BUILD_TYPE=Release"
    args << "-DALPSCore_DIR=#{Formula["alpscore"].opt_prefix}"
    system "cmake", ".", *args
    system "make"
    system "make", "test"
    system "make", "install"
  end

  test do
    system "false"
  end
end
