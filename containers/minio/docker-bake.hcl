# minio: what to build and with which versions (containers/AGENTS.md).
# The last release. Tags: https://github.com/minio/minio/tags
target "minio" {
  name       = "minio-debian${debian}"
  context    = "containers/minio"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=minio/minio
      { version = "RELEASE.2025-10-15T17-29-55Z", checksum = "9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("minio", debian, [base.version])
}
