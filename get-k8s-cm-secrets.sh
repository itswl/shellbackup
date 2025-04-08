#!/bin/bash

# 检查是否提供了命名空间参数
if [ -z "$1" ]; then
  echo "Please provide the namespace as an argument."
  exit 1
fi

NAMESPACE=$1

# 获取所有 Secret 名称
secrets=$(kubectl get secrets -n $NAMESPACE | grep Opaque | awk '{print $1}')
# 获取所有 ConfigMap 名称
configmaps=$(kubectl get configmap -n $NAMESPACE | awk '{if(NR>1) print $1}')

# 处理 Secret
for secret in $secrets; do
  echo "Processing Secret: $secret"

  # 获取 Secret 内容并提取 data 部分
  data=$(kubectl get secret $secret -n $NAMESPACE -o jsonpath='{.data}')

  # 检查 data 是否为空
  if [ -n "$data" ]; then
    echo "Secret $secret contains the following data fields:"

    # 遍历 data 中的每个键值对
    for key in $(echo "$data" | jq -r 'keys[]'); do
      # 提取并解码每个字段的 Base64 内容
      encoded_value=$(echo "$data" | jq -r ".[\"$key\"]")
      decoded_value=$(echo "$encoded_value" | base64 --decode)

      # 输出解码后的值
      echo "$key: $decoded_value"
    done
  else
    echo "Secret $secret contains no data fields"
  fi
  echo "---------------------------------"
  echo
  echo
done

# 处理 ConfigMap
for cm in $configmaps; do
  echo "Processing ConfigMap: $cm"

  # 获取 ConfigMap 内容并提取 data 部分
  data=$(kubectl get configmap $cm -n $NAMESPACE -o jsonpath='{.data}')

  # 检查 data 是否为空
  if [ -n "$data" ]; then
    echo "ConfigMap $cm contains the following data fields:"

    # 遍历 data 中的每个键值对
    for key in $(echo "$data" | jq -r 'keys[]'); do
      # 输出每个键值对的内容
      value=$(echo "$data" | jq -r ".[\"$key\"]")
      echo "$key: $value"
    done
  else
    echo "ConfigMap $cm contains no data fields"
  fi
  echo "---------------------------------"
  echo
  echo
done
