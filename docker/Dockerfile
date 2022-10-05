FROM FROM_IMAGE_NAME as init

ARG SERVICE_NAME

ARG STAGE

ARG AWS_REGION

ARG AWS_ACCESS_KEY_ID

ARG AWS_SECRET_ACCESS_KEY

ARG AWS_SESSION_TOKEN

ARG CONTAINER_WORDIR

FROM node:16 as processing

ARG SERVICE_NAME

ARG STAGE

ARG AWS_REGION

ARG AWS_ACCESS_KEY_ID

ARG AWS_SECRET_ACCESS_KEY

ARG AWS_SESSION_TOKEN

ARG CONTAINER_WORDIR

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip

RUN ./aws/install

RUN mkdir -p /app

WORKDIR /app

COPY --from=init ${CONTAINER_WORDIR} .

RUN pwd

RUN find /app -type f -name '*.js' -not -name '*.js.map' -not -path "/app/node_modules/*" -exec sed -i -e 's#sourceMappingURL=#sourceMappingURL=https://source-maps.lendis.io/'${SERVICE_NAME}'/'${STAGE}'/#g' "{}" \;

RUN rm -rf /app/**/*.js-e

RUN find /app -type f -name '*.js.map' -not -path "/app/node_modules/*" -exec echo "{}" \;

COPY script.sh script.sh

RUN bash -xe /app/script.sh ${AWS_ACCESS_KEY_ID} ${AWS_SECRET_ACCESS_KEY} ${AWS_SESSION_TOKEN} ${AWS_REGION} ${SERVICE_NAME} ${STAGE}

RUN rm -rf /app/script.sh

FROM FROM_IMAGE_NAME

ARG CONTAINER_WORDIR

RUN rm -rf ${CONTAINER_WORDIR}

COPY --from=processing /app ${CONTAINER_WORDIR}