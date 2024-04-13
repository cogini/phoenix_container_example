# phoenix_container_example

Full-featured production example of building, testing, and deploying
containerized Elixir/Phoenix apps.

Includes:

* Optimized Dockerfiles
* GitHub Actions for parallelized building, containerized testing, static code
  analysis, and deployment to AWS ECS
* Terraform code to set up AWS ECS, etc.
* Application configuration to support logging and tracing

See [Breaking up the monolith: building, testing, and deploying microservices](https://www.cogini.com/blog/breaking-up-the-monolith-building-testing-and-deploying-microservices/)
for background.

## Details

* Supports Debian, Ubuntu, and Alpine using
  [hexpm/elixir](https://hub.docker.com/r/hexpm/elixir) base images.
  Supports Google [Distroless](https://github.com/GoogleContainerTools/distroless)
  and Ubuntu [Chisel](https://github.com/canonical/chisel) to build small distribution images.

* Uses Erlang releases for the final image, resulting in an image size of less than 20MB.

* Uses Docker [BuildKit](https://github.com/moby/buildkit)
  for [multistage builds](https://docs.docker.com/develop/develop-images/multistage-build/)
  and caching of OS files and language packages. Multistage builds compile
  dependencies separately from app code, speeding rebuilds and reducing final
  image size. Caching of packages reduces size of container layers and allows
  sharing of data betwen container targets.

* Supports full-featured CI with Github Actions, building and testing
  components in parallel.

* Supports container-based testing, running tests against the production image
  using Postman/Newman, with containerized Postgres, MySQL, Redis, etc.

* Uses [docker-compose](https://docs.docker.com/compose/) to test multiple
  containers as a set. You can also run it on your local machine.

* Supports building multiple versions of images with different
  configurations, allowing testing of updated base images in response to
  security vulnerabilities.

* Supports development in a Docker container with Visual Studio Code.

* Supports compiling assets such as JS/CSS within the container, then
  uploading them to CloudFront CDN.

* Supports building for
  [multiple architectures](https://docs.docker.com/build/ci/github-actions/multi-platform/),
  e.g., AWS [Gravaton](https://aws.amazon.com/ec2/graviton/) Arm CPU.

* Supports deploying to AWS ECS with Blue/Green deployment and AWS Parameter
  Store for configuration. Terraform is used to set up the environment.

## Contact

Like what you see? We are happy to help you optimize your build system and
infrastructure. Contact `jakemorrison` on the [Elixir Slack](https://elixir-lang.slack.com)
or email `sales@cogini.com`.
