class BlueteamAutopilot < Formula
  include Language::Python::Virtualenv

  desc "SecOps agent powered by Qwen Cloud + ConnectOnion for multi-cloud security operations"
  homepage "https://github.com/cdavis-code/blueteam-autopilot"
  url "https://github.com/cdavis-code/blueteam-autopilot/archive/refs/tags/v3.1.0.tar.gz"
  sha256 ""  # Fill after creating GitHub release: curl -sL <url> | shasum -a 256
  license "MIT"

  depends_on "python@3.10"
  depends_on "aliyun-cli" => :optional

  resource "connectonion" do
    url "https://files.pythonhosted.org/packages/source/c/connectonion/connectonion-1.1.0.tar.gz"
    sha256 "a21803d79a9cfd944970158ba9a509ca34f983f02c8777d2e61ddae1c09b7a3e"
  end

  resource "mcp" do
    url "https://files.pythonhosted.org/packages/source/m/mcp/mcp-1.28.1.tar.gz"
    sha256 "2726bca5e7193f61c5dde8b12500a6de2d9acf6d1a1c0be9e8c2e706437991df"
  end

  resource "python-dotenv" do
    url "https://files.pythonhosted.org/packages/source/p/python-dotenv/python-dotenv-1.2.2.tar.gz"
    sha256 "1d8214789a24de455a8b8bd8ae6fe3c6b69a5e3d64aa8a8e5d68e694bbcb285a"
  end

  resource "libsql" do
    url "https://files.pythonhosted.org/packages/source/l/libsql/libsql-0.1.11.tar.gz"
    sha256 "c8c00c5e4d0906ff682ab3cad8473ef36aaa34080bcc553a2e636a73e79d9c2b"
  end

  resource "pyyaml" do
    url "https://files.pythonhosted.org/packages/source/P/PyYAML/pyyaml-6.0.3.tar.gz"
    sha256 "fc09d0aa354569bc501d4e787133afc08552722d3ab34836a80547331bb5d4a0"
  end

  def install
    virtualenv_install_with_resources

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
