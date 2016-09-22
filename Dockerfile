# docker build --rm -t sonarqube:6.0-rhel7 .
FROM registry.access.redhat.com/rhel7
MAINTAINER Red Hat Systems Engineering <refarch-feedback@redhat.com>

# Default to UTF-8 file.encoding
# Set the JAVA_HOME variable to make it clear where Java is located
ENV SONAR_VERSION=6.0 \
    SONAR_USER=sonarsrc \
    LANG=en_US.utf8 \
    JAVA_HOME=/usr/lib/jvm/jre

ENV SONARQUBE_HOME=/opt/$SONAR_USER/sonarqube \
    # Database configuration
    # Defaults to using H2
    SONARQUBE_JDBC_USERNAME=sonar \
    SONARQUBE_JDBC_PASSWORD=sonar \
    SONARQUBE_JDBC_URL=

# Http port
EXPOSE 9000

RUN set -x \
    && groupadd -r $SONAR_USER -g 1000 && useradd -u 1000 -r -g $SONAR_USER -m -s /sbin/nologin -c "$SONAR_USER user" $SONAR_USER \
    && mkdir -p /opt/$SONAR_USER && chmod 755 /opt/$SONAR_USER \
    && chown $SONAR_USER:$SONAR_USER /opt/$SONAR_USER \
    && yum clean all \
    && yum-config-manager -q --disable \* \
    && yum-config-manager --enable rhel-7-server-rpms \
    && yum -y install --setopt=tsflags=nodocs deltarpm \
    && yum -y update-minimal --security --sec-severity=Important --sec-severity=Critical --setopt=tsflags=nodocs \
    && yum -y install unzip java-1.8.0-openjdk \
    && yum clean all

# Specify the user which should be used to execute all commands below
USER $SONAR_USER

# Set the working directory to sonar user home directory
WORKDIR /opt/$SONAR_USER

RUN set -x \
    # pub   2048R/D26468DE 2015-05-25
    #       Key fingerprint = F118 2E81 C792 9289 21DB  CAB4 CFCA 4A29 D264 68DE
    # uid                  sonarsource_deployer (Sonarsource Deployer) <infra@sonarsource.com>
    # sub   2048R/06855C1D 2015-05-25
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys F1182E81C792928921DBCAB4CFCA4A29D26468DE \
    && curl -o sonarqube.zip -SL https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip --retry 999 --retry-max-time 0 -C - \
    && curl -o sonarqube.zip.asc -SL https://sonarsource.bintray.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip.asc --retry 999 --retry-max-time 0 -C - \
    && gpg --batch --verify sonarqube.zip.asc sonarqube.zip \
    && unzip sonarqube.zip \
    && mv sonarqube-$SONAR_VERSION sonarqube \
    && rm sonarqube.zip* \
    && rm -rf $SONARQUBE_HOME/bin/*

RUN echo $'#!/bin/bash\n\
set -e; \
if [ "${1:0:1}" != '-' ]; then \
  exec "$@"; \
fi; \
exec java -jar lib/sonar-application-$SONAR_VERSION.jar \
-Dsonar.log.console=true \
-Dsonar.jdbc.username="$SONARQUBE_JDBC_USERNAME" \
-Dsonar.jdbc.password="$SONARQUBE_JDBC_PASSWORD" \
-Dsonar.jdbc.url="$SONARQUBE_JDBC_URL" \
-Dsonar.web.javaAdditionalOpts="$SONARQUBE_WEB_JVM_OPTS -Djava.security.egd=file:/dev/./urandom" \
"$@"' > $SONARQUBE_HOME/bin/run.sh \
    && chmod u+x $SONARQUBE_HOME/bin/run.sh

## Atomic Labels
# The UNINSTALL label by DEFAULT will attempt to delete a container (rm) and image (rmi) if the container NAME is the same as the actual IMAGE
# NAME is set via -n flag to ALL atomic commands (run,stop,uninstall)
LABEL name="sonarqube" \
      vendor="SonarSource" \
      version="6.0-rhel7" \
      summary="SonarQube" \
      description="SonarQube" \
      RUN='docker run -di \
            --name ${NAME}_run \
            -p 9000:9000 \
            -p 9092:9092 \
            $IMAGE' \
      STOP='docker stop ${NAME}_run && echo "Container ${NAME}_run has been stopped"' \
      UNINSTALL='docker rm ${NAME}_run && echo "Uninstallation complete"'

## OpenShift labels
LABEL io.k8s.description="SonarQube" \
      io.k8s.display-name="SonarQube" \
      io.openshift.build.commit.author="Tommy Hughes <tohughes@redhat.com>" \
      io.openshift.expose-services="9000:9000" \
      io.openshift.tags="SonarQube,sonarqube,sonar"

VOLUME ["$SONARQUBE_HOME/data", "$SONARQUBE_HOME/extensions"]
WORKDIR $SONARQUBE_HOME
ENTRYPOINT ["./bin/run.sh"]
