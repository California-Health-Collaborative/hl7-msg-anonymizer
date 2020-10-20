ARG IMAGE=intersystemsdc/irishealth-community:2020.3.0.221.0-zpm
FROM $IMAGE

USER root   
        
WORKDIR /opt/irisapp
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp
USER ${ISC_PACKAGE_MGRUSER}

RUN mkdir /tmp/hl7 && mkdir /tmp/hl7/in && mkdir /tmp/hl7/out && chmod a+w /tmp/hl7/out

COPY  Installer.cls .
COPY  src src
COPY iris.script /tmp/iris.script
COPY misc/hl7/ADT_A01Massie.hl7 /tmp/hl7/in/ADT_A01Massie.hl7

RUN iris start IRIS \
	&& iris session IRIS < /tmp/iris.script \
    && iris stop IRIS quietly
