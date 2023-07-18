FROM python:3.7-slim

RUN pip install shioaji==1.1.8 --use-feature=2020-resolver
