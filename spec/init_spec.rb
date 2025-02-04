RSpec.describe Rum do
  describe "::init" do
    it "should print an empty Rumfile" do
      exp = <<~EOS
        #!/usr/bin/env ruby
        rum :"test_image" do
        end
      EOS
      allow($stderr).to receive(:write)
      allow(File).to receive(:exist?).and_return false
      expect { Rum.init "test_image" }.to output(exp).to_stdout
    end

    it "should print an empty Rumfile because the stage is unnamed" do
      dockerfile = <<~EOS
        FROM ruby
      EOS
      exp = <<~EOS
        #!/usr/bin/env ruby
        rum :"test_image" do
        end
      EOS
      allow($stderr).to receive(:write)
      allow(File).to receive(:exist?).and_return true
      allow(File).to receive(:read).and_return dockerfile
      expect { Rum.init "test_image" }.to output(exp).to_stdout
    end

    it "should print a single named stage Rumfile" do
      dockerfile = <<~EOS
        FROM ruby AS build
      EOS
      exp = <<~EOS
        #!/usr/bin/env ruby
        rum :"test_image" do
          stage :"build"
        end
      EOS
      allow($stderr).to receive(:write)
      allow(File).to receive(:exist?).and_return true
      allow(File).to receive(:read).and_return dockerfile
      expect { Rum.init "test_image" }.to output(exp).to_stdout
    end

    it "should print an empty Rumfile because the stages are unnamed" do
      dockerfile = <<~EOS
        FROM ruby
        FROM ruby
      EOS
      exp = <<~EOS
        #!/usr/bin/env ruby
        rum :"test_image" do
        end
      EOS
      allow($stderr).to receive(:write)
      allow(File).to receive(:exist?).and_return true
      allow(File).to receive(:read).and_return dockerfile
      expect { Rum.init "test_image" }.to output(exp).to_stdout
    end

    it "should print a named multi-stage Rumfile with deps" do
      dockerfile = <<~EOS
        FROM ruby AS build
        FROM ruby AS test
      EOS
      exp = <<~EOS
        #!/usr/bin/env ruby
        rum :"test_image" do
          stage :"build"
          stage :"test" => :"build"
        end
      EOS
      allow($stderr).to receive(:write)
      allow(File).to receive(:exist?).and_return true
      allow(File).to receive(:read).and_return dockerfile
      expect { Rum.init "test_image" }.to output(exp).to_stdout
    end
  end

  describe "::gets_image" do
    it "should return the default" do
      allow($stderr).to receive(:write)
      ret = Rum.send :gets_image, nil, StringIO.new("\n")
      exp = Rum::Docker::Image.parse(File.split(Dir.pwd).last)
      expect(ret.to_a).to eq(exp.to_a)
    end

    it "should read the image from STDIN" do
      allow($stderr).to receive(:write)
      ret = Rum.send :gets_image, nil, StringIO.new("my_image\n")
      exp = Rum::Docker::Image.parse("my_image")
      expect(ret.to_a).to eq(exp.to_a)
    end
  end
end
