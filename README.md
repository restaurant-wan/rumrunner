[![Rum Runner](https://github.com/amancevice/rumrunner/blob/master/rumrunner.png?raw=true)](https://github.com/amancevice/rumrunner)
[![Build Status](https://travis-ci.com/amancevice/rumrunner.svg?branch=master)](https://travis-ci.com/amancevice/rumrunner)
[![Gem Version](https://badge.fury.io/rb/rumrunner.svg)](https://badge.fury.io/rb/rumrunner)
[![Test Coverage](https://api.codeclimate.com/v1/badges/4b56853acc5cbb254125/test_coverage)](https://codeclimate.com/github/amancevice/rumrunner/test_coverage)
[![Maintainability](https://api.codeclimate.com/v1/badges/4b56853acc5cbb254125/maintainability)](https://codeclimate.com/github/amancevice/rumrunner/maintainability)


Rum Runner is a Rake-based utility for building multi-stage Dockerfiles.

Users can pair a multi-stage Dockerfile with a Rumfile that uses a Rake-like DSL to customize each stage's build options and dependencies.

The `rum` executable allows users to easily invoke builds, shell-into specific stages for debugging, and export artifacts from built containers.

Rum Runner has the following features:
* Fully compatible with Rake
* Rake-like DSL/CLI that enable simple annotation and execution of builds
* Rumfiles are completely defined in standard Ruby syntax, like Rakefiles
* Users can chain Docker build stages with prerequisites
* Artifacts can be exported from stages
* Shell tasks are automatically provided for every stage
* Stage, artifact, and shell, steps can be customized

**Origins**

This project was born from using Makefiles to drive multi-stage builds. For the most part this worked really well, but it became a bit of an ordeal to write for more complex projects. This tool is an attempt to recreate that general technique with minimal annotation and limited assumptions.

View the docs on [rubydoc.info](https://www.rubydoc.info/github/amancevice/rumrunner)

## Installation

```bash
gem install rumrunner
```

## Quickstart

Use the `Rum.init` helper to create a template Rumfile for your project:

```bash
gem install rumrunner
ruby -r rumrunner -e Rum.init > Rumfile
rum --tasks
```

## Example

Imagine a simple multi-stage Dockerfile:

```Dockerfile
FROM ruby AS build
# Run build steps here...

FROM ruby AS test
# Run test steps here...

FROM ruby AS deploy
# Run deploy steps here...
```

Create `Rumfile` and describe your build:

```ruby
rum :image_name do
  tag "1.2.3"

  stage :build
  stage :test => :build
  stage :deploy => :test

  # rum build  => docker build --target build  --tag image_name:1.2.3-build .
  # rum test   => docker build --target test   --tag image_name:1.2.3-test .
  # rum deploy => docker build --target deploy --tag image_name:1.2.3-deploy .
end
```

Run `rum --tasks` to view the installed tasks:

```bash
rum build                # Build `build` stage
rum build:clean          # Remove any temporary images and products from `build` stage
rum build:shell[shell]   # Shell into `build` stage
rum clean                # Remove any temporary images and products
rum clobber              # Remove any generated files
rum deploy               # Build `deploy` stage
rum deploy:clean         # Remove any temporary images and products from `deploy` stage
rum deploy:shell[shell]  # Shell into `deploy` stage
rum test                 # Build `test` stage
rum test:clean           # Remove any temporary images and products from `test` stage
rum test:shell[shell]    # Shell into `test` stage
```

## Naming Convention

The name of the images are taken from the first argument to the main block and appended with the name of the stage.

In the above example, built images would build be named:

- `image_name:1.2.3-build`
- `image_name:1.2.3-test`
- `image_name:1.2.3-deploy`

The first argument to the main block can be any Docker image reference:

```ruby
rum :"registry:5000/username/image" do
  #...
end
```

## Digest Location

Images build with the `stage` task have their digests cached for easy lookup.

The default location for the digests is in `.docker`, but that can be modified:

```ruby
rum :image_name => "tmp" do
  # ...
end
```

## Build vs. Run

At the core, every directive within the `rum` block will eventually be interpreted as either a `docker build` or a `docker run` command. The type of directive is simply a way of specifying defaults for the command.

If you simply wish to define a named task that executes a build or a run, you can use the `build` or `run` directives:

```ruby
rum :image_name do
  build :fizz do
    tag  "image_name"
    path "."
  end

  run :buzz do
    rm    true
    image "image_name"
    cmd   %w{echo hello}
  end

  # rum fizz => docker build --tag image_name .
  # rum buzz => docker run --rm image_name echo hello
end
```

## Blocks

The methods inside blocks for `build`, `run`, `stage`, `artifact`, and `shell` tasks are dynamically handled. Any option you might pass to the `docker run` or `docker build` command can be used.

Simply drop any leading `-`s from the option and convert to snake-case. Eg, `--build-arg` becomes `build_arg`; `--env-file` becomes `env_file`.

## Shared ENV variables

The `env` method can be invoked in the `rum` block to declare a value that will be passed to all stages/artifacts/shells. For stages, the value will be passed using the `--build-arg` option; for artifacts and shells, the `--env` option.

```ruby
rum :image_name do
  env :FIZZ => :BUZZ

  stage :build

  artifact "pkg.zip" => :build

  # rum build   => docker build --build-arg FIZZ=BUZZ ...
  # rum pkg.zip => docker run --env FIZZ=BUZZ ...
end
```

## Shells

Run a stage task to build the image up to that stage and cache the image digest.

Run with the `:shell` suffix to build the image and then shell into an instance of the image running as a temporary container.

The default shell is `/bin/sh`, but this can be overridden at runtime with the task arg, eg. `rum build:shell[/bin/bash]`

## Customize Shells

By default, all stages have a `:shell` task that can be invoked to build and shell into a container for a stage. By default the container is run as an ephemeral container (`--rm`) in interactive with TTY allocated and a bash shell open.

Customize the shell for a stage with the `shell` method:

```ruby
rum :image_name do
  stage :dev

  shell :dev do
    entrypoint "/bin/zsh"
    rm         false
    volume     "#{Dir.pwd}:/var/task/"
  end

  # rum dev => docker run --entrypoint /bin/zsh --volume $PWD:/var/task/ ...
end
```

## Customize Stages

Stages can be customized with blocks:

```ruby
rum :image_name do
  tag "1.2.3"

  stage :build

  stage :test => :build

  stage :deploy => :test do
    build_arg :AWS_ACCESS_KEY_ID
    build_arg :AWS_SECRET_ACCESS_KEY
    build_arg :AWS_DEFAULT_REGION => "us-east-1"
    label     :Fizz
  end
end
```

Methods invoked inside the stage block are interpreted as options for the eventual `docker build` command.

## Export Artifacts

Use the `artifact` method to specify an artifact to be exported from the image.

```ruby
rum :image_name do
  stage :build

  artifact "package.zip" => :build
end
```

By default the container simply `cat`s the file from the container to the local file system, but more complex exports can be defined:

```ruby
rum :image_name do
  stage :build

  artifact "package.zip" => :build do
    workdir "/var/task/"
    cmd     %w[zip -r - .]
  end
end
```

Methods invoked inside the artifact block are interpreted as options for the eventual `docker run` command.

## Default Task

Use the `default` method to set a default task when running the bare `rum` executable:

```ruby
rum :image_name do
  stage :build

  artifact "package.zip" => :build

  default "package.zip"
end
```

## Integrate with Rake

It isn't strictly necessary to include a `Rumfile` in your project. Rum Runner can be included in any `Rakefile` and run with the `rake` command:

```ruby
# ./Rakefile

require "rumrunner"

namespace :rum do
  rum :image_name do
    stage :build
    stage :test => :build
  end
end
```

```bash
$ rake --tasks

rake rum:build # ...
rake rum:test  # ...
```
