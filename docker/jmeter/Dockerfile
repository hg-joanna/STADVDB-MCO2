FROM eclipse-temurin:17-jdk-alpine

# Install JMeter
ENV JMETER_VERSION=5.6.3
ENV JMETER_HOME=/opt/apache-jmeter-${JMETER_VERSION}
ENV JMETER_BIN=${JMETER_HOME}/bin
ENV PATH=${JMETER_BIN}:${PATH}

# Install dependencies
RUN apk update && apk add --no-cache wget ca-certificates

# Download and extract JMeter
RUN wget -q https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz -O /tmp/jmeter.tgz \
  && tar -xzf /tmp/jmeter.tgz -C /opt \
  && rm /tmp/jmeter.tgz

# Set JMeter properties for headless operation
RUN echo "java.awt.headless=true" >> ${JMETER_HOME}/bin/jmeter.properties

WORKDIR /test

# Always run JMeter in non-GUI mode by default
ENTRYPOINT ["/opt/apache-jmeter-5.6.3/bin/jmeter", "-n"]
