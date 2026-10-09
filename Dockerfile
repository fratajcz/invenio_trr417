# syntax=docker/dockerfile:1
#
# SPDX-FileCopyrightText: 2026 Northwestern University.
# SPDX-FileCopyrightText: 2026 Frontmatter.
# SPDX-FileCopyrightText: 2026 KTH Royal Institute of Technology.
# SPDX-License-Identifier: MIT
FROM ghcr.io/inveniosoftware/invenio:14-debian AS base

FROM base AS builder

COPY README.md pyproject.toml uv.lock ./
COPY site ./site
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable

COPY ./docker/uwsgi/ ${INVENIO_INSTANCE_PATH}
COPY ./invenio.cfg ${INVENIO_INSTANCE_PATH}
COPY ./templates/ ${INVENIO_INSTANCE_PATH}/templates/
COPY ./app_data/ ${INVENIO_INSTANCE_PATH}/app_data/
COPY ./translations/ ${INVENIO_INSTANCE_PATH}/translations/
COPY ./assets/ ./assets/
COPY ./static/ ./static/

RUN cp -r ./static/. ${INVENIO_INSTANCE_PATH}/static/ && \
    cp -r ./assets/. ${INVENIO_INSTANCE_PATH}/assets/ && \
    invenio collect --verbose && \
    invenio webpack buildall && \
    rm -rf ${INVENIO_INSTANCE_PATH}/assets && \
    rm -rf \
        /root/.cache \
        /tmp/* \
        ${INVENIO_INSTANCE_PATH}/assets/node_modules \
        ${INVENIO_INSTANCE_PATH}/assets/.cache

FROM base AS app-base

COPY . .
COPY --from=builder ${WORKING_DIR}/src/.venv ./.venv
COPY --from=builder ${INVENIO_INSTANCE_PATH}/static/ ${INVENIO_INSTANCE_PATH}/static/
COPY ./docker/uwsgi/ ${INVENIO_INSTANCE_PATH}
COPY ./invenio.cfg ${INVENIO_INSTANCE_PATH}
COPY ./templates/ ${INVENIO_INSTANCE_PATH}/templates/
COPY ./app_data/ ${INVENIO_INSTANCE_PATH}/app_data/
COPY ./translations/ ${INVENIO_INSTANCE_PATH}/translations/

ENV INVENIO_USER_ID=1000
RUN chgrp -R 0 ${WORKING_DIR} && \
    chmod -R g=u ${WORKING_DIR} && \
    #useradd invenio --uid ${INVENIO_USER_ID} --gid 0 && \
    chown -R invenio:root ${WORKING_DIR}

USER ${INVENIO_USER_ID}:${INVENIO_USER_ID}

ENTRYPOINT ["bash", "-c"]
