#!/bin/bash

# Copyright 2024 孔令飞 <colin404@foxmail.com>. All rights reserved.
# Use of this source code is governed by a MIT style
# license that can be found in the LICENSE file. The original repo for
# this file is https://github.com/onexstack/miniblog. The professional
# version of this repository is https://github.com/onexstack/onex.


for n in $(seq 1 1 10)
do
    nohup curl -XGET http://onexstack.com:7777/healthz &>/dev/null
done
