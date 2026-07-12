class BlueteamAutopilot < Formula
  include Language::Python::Virtualenv

  desc "SecOps agent powered by Qwen Cloud + ConnectOnion for multi-cloud security operations"
  homepage "https://github.com/cdavis-code/blueteam-autopilot"
  url "https://github.com/cdavis-code/blueteam-autopilot/archive/refs/tags/v3.1.4.tar.gz"
  sha256 "b397ab7695ad3975fc68aa03b7e0a1ba96c2854d79dcbfe1911b6c5e9bea6b43"
  license "MIT"

  depends_on "python@3.12"
  depends_on "aliyun-cli" => :optional

  resource "connectonion" do
    url "https://files.pythonhosted.org/packages/source/c/connectonion/connectonion-1.1.0.tar.gz"
    sha256 "5c42be1527feddbf8d5a4ec3e779a036095e039ac40b14b70bc2840d127406ab"
  end

  resource "mcp" do
    url "https://files.pythonhosted.org/packages/source/m/mcp/mcp-1.28.1.tar.gz"
    sha256 "d51e36a5f5644faea4f85ea649bfffa6bc6c26770d42798ad6a3de3d2ba69683"
  end

  resource "python-dotenv" do
    url "https://files.pythonhosted.org/packages/82/ed/0301aeeac3e5353ef3d94b6ec08bbcabd04a72018415dcb29e588514bba8/python_dotenv-1.2.2.tar.gz"
    sha256 "2c371a91fbd7ba082c2c1dc1f8bf89ca22564a087c2c287cd9b662adde799cf3"
  end

  resource "libsql" do
    url "https://files.pythonhosted.org/packages/source/l/libsql/libsql-0.1.11.tar.gz"
    sha256 "101b6e60f5333434b3e6107bfe2cf24cd5d1317286ad262cb6489941abde77d4"
  end

  resource "pyyaml" do
    url "https://files.pythonhosted.org/packages/source/P/PyYAML/pyyaml-6.0.3.tar.gz"
    sha256 "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f"
  end

  def install
    # Use virtualenv_install_with_resources but allow binary wheels for native packages
    venv = virtualenv_create(libexec, "python3.12")
    
    # Install resources in order, allowing binary wheels for libsql (Rust package)
    resources.each do |r|
      if r.name == "libsql"
        # Install libsql from PyPI to use pre-built wheels (has Rust extensions)
        system "#{libexec}/bin/python", "-m", "pip", "install", 
               "--no-deps", "--only-binary", "libsql", "libsql==0.1.11"
      else
        # Use build isolation for packages that need it (e.g., mcp requires hatchling)
        r.stage do
          system "#{libexec}/bin/python", "-m", "pip", "install", 
                 "--no-deps", "."
        end
      end
    end

    # Install the main package (creates the blueteam entry point)
    system "#{libexec}/bin/python", "-m", "pip", "install", "."

    # Link the blueteam entry point
    bin.install_symlink libexec/"bin/blueteam" => "blueteam"
  end

  def caveats
    <<~EOS
      BlueTeam is installed. To get started:

        blueteam

      Demo mode is the default (no Alibaba Cloud credentials needed).
      Set DASHSCOPE_API_KEY in ~/.blueteam/.env for Qwen Cloud access.

      For live Alibaba Cloud APIs:
        brew install aliyun-cli
        aliyun configure
        echo 'SECURITY_CENTER_MODE=real' >> ~/.blueteam/.env
    EOS
  end

  test do
    assert_match "BlueTeam", shell_output("#{bin}/blueteam --help 2>&1", 0)
  end
end
