#!/bin/bash
yum update -y && yum install -y
yum install git -y
yum install pip -y
#curl -O https://bootstrap.pypa.io/get-pip.py && python3 get-pip.py --user
git clone https://github.com/Nate-Wil/tech-challenge-flask-app-main.git && export TC_DYNAMO_TABLE=Candidates



cd tech-challenge-flask-app-main && pip3 install -r requirements.txt

gunicorn -b 0.0.0.0 app:candidates_app #echo  -ne '\n'
