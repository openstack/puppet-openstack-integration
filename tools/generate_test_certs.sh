#!/usr/bin/env bash
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
pushd $(dirname -- "$0")/../files

# Remove existing files
rm *.key *.csr *.crt *.srl

openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
  -subj "/C=AU/ST=State CA/L=CA/O=OpenStack CA Org/OU=OpenStack Test CA/CN=Openstack Test Certificate Authority/emailAddress=admin@ca.example.com/" \
  -addext "keyUsage=critical,digitalSignature,keyCertSign"

openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.csr \
  -subj "/C=AU/ST=State CA/L=State1/O=OpenStack Test Org/OU=OpenStack Test Unit/CN=test.example.com/" \
  -addext "subjectAltName=IP:127.0.0.1,IP:::1"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 3650 -sha256 -copy_extensions copyall

# Remove unused files
rm *.csr
rm ca.key
rm ca.srl

popd
