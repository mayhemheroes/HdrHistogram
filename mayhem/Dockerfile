# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile — JVM/Jazzer target (Maven + Jazzer standalone). Builds ON TOP of the org
# C/C++ base (ghcr.io/mayhemheroes/base) — clang links the ELF launcher shims that drive Jazzer.
#
# Build (from the repo root, on the `mayhem` branch):
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile \
#       --build-arg COMMIT=$(git rev-parse HEAD) \
#       [--build-arg SOURCE_DATE_EPOCH=$(date +%s)] -t mytag .

FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
ARG SOURCE_DATE_EPOCH
ARG SANITIZER_FLAGS
ARG MAYHEM_JOBS=

ARG MAVEN_VERSION=3.9.9
ARG MAVEN_SHA256=7a9cdf674fc1703d6382f5f330b3d110ea1b512b51f1652846d9e4e8a588d766
ARG JDK_VERSION=17.0.14+7
ARG JDK_SHA256=a3af83983fb94dd7d11b13ba2dba0fb6819dc2caaf87e6937afd22ad4680ae9a
ARG JAZZER_VERSION=0.26.0
ARG JAZZER_SHA256=816b29fe8796e12ac0c8194dc47d4c245a21df6b00376e7ab42120ec985e3a42

ENV JVM_PREFIX=/opt/toolchains/jvm \
    MAVEN_HOME=/opt/toolchains/maven \
    JAVA_HOME=/opt/toolchains/jvm/jdk \
    JVM_LD_LIBRARY_PATH=/opt/toolchains/jvm/jdk/lib/server \
    PATH=/opt/toolchains/maven/bin:/opt/toolchains/jvm/jdk/bin:${PATH}

USER root
RUN install -d /opt/toolchains/jvm \
 && apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.14%2B7/OpenJDK17U-jdk_x64_linux_hotspot_17.0.14_7.tar.gz" \
      -o /tmp/jdk.tgz \
 && echo "${JDK_SHA256}  /tmp/jdk.tgz" | sha256sum -c - \
 && tar -xzf /tmp/jdk.tgz -C /opt/toolchains/jvm \
 && mv /opt/toolchains/jvm/jdk-17.0.14+7 /opt/toolchains/jvm/jdk \
 && rm -f /tmp/jdk.tgz \
 && curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
      -o /tmp/maven.tgz \
 && echo "${MAVEN_SHA256}  /tmp/maven.tgz" | sha256sum -c - \
 && tar -xzf /tmp/maven.tgz -C /opt/toolchains \
 && mv "/opt/toolchains/apache-maven-${MAVEN_VERSION}" /opt/toolchains/maven \
 && rm -f /tmp/maven.tgz \
 && curl -fsSL "https://github.com/CodeIntelligenceTesting/jazzer/releases/download/v${JAZZER_VERSION}/jazzer-linux-x86-64.tar.gz" \
      -o /tmp/jazzer.tgz \
 && echo "${JAZZER_SHA256}  /tmp/jazzer.tgz" | sha256sum -c - \
 && tar -xzf /tmp/jazzer.tgz -C /opt/toolchains/jvm \
 && mv /opt/toolchains/jvm/jazzer /opt/toolchains/jvm/jazzer_driver \
 && chmod +x /opt/toolchains/jvm/jazzer_driver \
 && rm -f /tmp/jazzer.tgz \
 && chown -R 2000:2000 /opt/toolchains/jvm /opt/toolchains/maven

USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
