FROM python:3.7-slim

RUN pip install shioaji==1.1.10 --use-feature=2020-resolver
