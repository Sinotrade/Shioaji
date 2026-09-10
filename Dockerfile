FROM python:3.13-slim

ARG SHIOAJI_VERSION="v1.7.5"

RUN pip install --no-cache-dir "shioaji==${SHIOAJI_VERSION#v}"
