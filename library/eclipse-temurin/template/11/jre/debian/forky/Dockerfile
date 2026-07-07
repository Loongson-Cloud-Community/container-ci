# ------------------------------------------------------------------------------
#             NOTE: THIS FILE IS GENERATED VIA "generate_dockerfiles.py"
#
#                       PLEASE DO NOT EDIT IT DIRECTLY.
# ------------------------------------------------------------------------------
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

FROM lcr.loongnix.cn/library/debian:forky

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH=$JAVA_HOME/bin:$PATH

# Default to UTF-8 file.encoding
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        locales \
    && rm -rf /var/lib/apt/lists/* \
    && localedef -i en_US -c -f UTF-8 en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

ENV JAVA_VERSION=11.0.31+11

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH=$JAVA_HOME/bin:$PATH

# 复制预构建的 tarball
COPY OpenJDK11U-jre_loongarch64_linux_hotspot_11.0.31_11.tar.gz /tmp/openjdk.tar.gz

RUN mkdir -p "$JAVA_HOME" && \
    tar -xzf /tmp/openjdk.tar.gz -C "$JAVA_HOME" --strip-components=1 && \
    rm /tmp/openjdk.tar.gz

RUN set -eux; \
    echo "Verifying install ..."; \
    echo "java --version"; java --version; \
    echo "Complete."
COPY --chmod=755 entrypoint.sh /__cacert_entrypoint.sh
ENTRYPOINT ["/__cacert_entrypoint.sh"]
