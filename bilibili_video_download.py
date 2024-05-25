# -*- coding : utf-8 -*-
# @Time : 2021/3/21 16:11
# @Author : wawyw
# @File : bilibili_video.py
# @Software : PyCharm

import requests
import re
import json
import subprocess
import os
import shutil

headers = {"user-agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.4389.90 Safari/537.36","referer": "https://message.bilibili.com/"
}

def send_request(url):
    response = requests.get(url=url, headers=headers)
    return response

def get_video_data(html_data):
    title = re.findall('<title data-vue-meta="true">(.*?)</title>',html_data)[0].replace("_哔哩哔哩 (゜-゜)つロ 干杯~-bilibili","")
    json_data = re.findall(r'<script>window.__playinfo__=(.*?)</script>',html_data)[0]
    json_data = json.loads(json_data)
    audio_url = json_data["data"]["dash"]["audio"][0]["backupUrl"][0]
    video_url = json_data["data"]["dash"]["video"][0]["backupUrl"][0]
    video_data = [title, audio_url, video_url]
    return video_data

def save_data(file_name,audio_url,video_url):
    print("正在下载 " + file_name + "的音频...")
    audio_data = send_request(audio_url).content
    print("完成下载 " + file_name + "的音频！")
    print("正在下载 " + file_name + "的视频...")
    video_data = send_request(video_url).content
    print("完成下载 " + file_name + "的视频！")
    with open(file_name + ".mp3", "wb") as f:
        f.write(audio_data)
    with open(file_name + ".mp4", "wb") as f:
        f.write(video_data)

def merge_data(video_name):
    os.rename(video_name + ".mp3","1.mp3")
    os.rename(video_name + ".mp4","1.mp4")
    shutil.move("1.mp3","ffmpeg/bin/1.mp3")
    shutil.move("1.mp4","ffmpeg/bin/1.mp4")
    print("正在合并 " + video_name + "的视频...")
    os.chdir("ffmpeg/bin/")
    subprocess.call("ffmpeg -i 1.mp4 -i 1.mp3 -c:v copy -c:a aac -strict experimental output.mp4", shell=True)
    os.rename("output.mp4", video_name + ".mp4")
    os.remove("1.mp3")
    os.remove("1.mp4")
    shutil.move("%s.mp4"%video_name,"../../%s.mp4"%video_name)
    print("完成合并 " + video_name + "的视频！")

def main():
    url = input("输入bilibili视频对应的链接即可下载：\n")
    html_data = send_request(url).text
    video_data = get_video_data(html_data)
    save_data(video_data[0],video_data[1],video_data[2])
    merge_data(video_data[0])

if __name__ == "__main__":
    main()









