// const fs = require('fs');
// const yaml = require('js-yaml');

function main(params) {

  // 香港地区
  const hongKongRegex = /香港|HK|Hong|🇭🇰/;
  const hongKongProxies = getProxiesByRegex(params, hongKongRegex);
  // 台湾地区
  const taiwanRegex = /台湾|TW|Taiwan|Wan|🇨🇳|🇹🇼/;
  const taiwanProxies = getProxiesByRegex(params, taiwanRegex);
  // 狮城地区
  const singaporeRegex = /新加坡|狮城|SG|Singapore|🇸🇬/;
  const singaporeProxies = getProxiesByRegex(params, singaporeRegex);
  // 日本地区
  const japanRegex = /日本|JP|Japan|🇯🇵/;
  const japanProxies = getProxiesByRegex(params, japanRegex);
  // 美国地区
  const americaRegex = /美国|US|United States|America|🇺🇸/;
  const americaProxies = getProxiesByRegex(params, americaRegex);
  // 其他地区
  const othersRegex = /^(?!.*(?:香港|HK|Hong|🇭🇰|台湾|TW|Taiwan|Wan|🇨🇳|🇹🇼|新加坡|SG|Singapore|狮城|🇸🇬|日本|JP|Japan|🇯🇵|美国|US|States|America|🇺🇸|自动|故障|流量|官网|套餐|机场|订阅|年|月)).*$/;
  const othersProxies = getProxiesByRegex(params, othersRegex);
  // 所有地区
  const allRegex = /^(?!.*(?:自动|故障|流量|官网|套餐|机场|订阅|年|月|失联|频道)).*$/;
  const allProxies = getProxiesByRegex(params, allRegex);

  // 香港
  const HongKong = {
    name: "HongKong",
    type: "url-test",
    url: "http://www.gstatic.com/generate_204",
    icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Hong_Kong.png",
    interval: 300,
    tolerance: 20,
    timeout: 2000,
    lazy: true,
    proxies: hongKongProxies.length > 0 ? hongKongProxies : ["DIRECT"]
  };
  // 台湾
  const TaiWan = {
    name: "TaiWan",
    type: "url-test",
    url: "http://www.gstatic.com/generate_204",
    icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Taiwan.png",
    interval: 300,
    tolerance: 20,
    timeout: 2000,
    lazy: true,
    proxies: taiwanProxies.length > 0 ? taiwanProxies : ["DIRECT"]
  };
  // 狮城
  const Singapore = {
    name: "Singapore",
    type: "url-test",
    url: "http://www.gstatic.com/generate_204",
    icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Singapore.png",
    interval: 300,
    tolerance: 20,
    timeout: 2000,
    lazy: true,
    proxies: singaporeProxies.length > 0 ? singaporeProxies : ["DIRECT"]
  };
  // 日本
  const Japan = {
    name: "Japan",
    type: "url-test",
    url: "http://www.gstatic.com/generate_204",
    icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Japan.png",
    interval: 300,
    tolerance: 20,
    timeout: 2000,
    lazy: true,
    proxies: japanProxies.length > 0 ? japanProxies : ["DIRECT"]
  };
  // 美国
  const America = {
    name: "America",
    type: "url-test",
    url: "http://www.gstatic.com/generate_204",
    icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/United_States.png",
    interval: 300,
    tolerance: 20,
    timeout: 2000,
    lazy: true,
    proxies: americaProxies.length > 0 ? americaProxies : ["DIRECT"]
  };
  // 其他
  const Others = {
    name: "Others",
    type: "url-test",
    url: "http://www.gstatic.com/generate_204",
    icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/World_Map.png",
    interval: 300,
    tolerance: 20,
    timeout: 2000,
    lazy: true,
    proxies: othersProxies.length > 0 ? othersProxies : ["DIRECT"]
  };
  // 自动
  const Auto = {
    name: "Auto",
    type: "url-test",
    url: "http://www.gstatic.com/generate_204",
    icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Auto.png",
    interval: 300,
    tolerance: 20,
    timeout: 2000,
    lazy: true,
    proxies: allProxies.length > 0 ? allProxies : ["DIRECT"]
  };
  // 负载均衡
  const Balance = {
    name: "Balance",
    type: "load-balance",
    url: "http://www.gstatic.com/generate_204",
    icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Available.png",
    interval: 300,
    strategy: "consistent-hashing",
    lazy: true,
    proxies: allProxies.length > 0 ? allProxies : ["DIRECT"]
  };
  // 故障转移
  const Fallback = {
    name: "Fallback",
    type: "fallback",
    url: "http://www.gstatic.com/generate_204",
    icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Bypass.png",
    interval: 300,
    timeout: 2000,
    lazy: true,
    proxies: allProxies.length > 0 ? allProxies : ["DIRECT"]
  };

   // 国外分组
  const G = ["Balance", "Proxy", "Auto", "Fallback", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"];
  // 国内分组
  const M = ["DIRECT", "Proxy", "Auto", "Balance", "Fallback", "HongKong", "TaiWan", "Singapore", "Japan", "America", "Others"];
  // AI分组
  const AI = ["Proxy", "America", "Japan", "Singapore", "TaiWan", "HongKong", "Others", "Balance"];

  // 漏网之鱼
  const Final = { name: "Final", type: "select", proxies: ["DIRECT", "Global", "Proxy"], icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Final.png" };
  // 手动选择
  const Proxy = { name: "Proxy", type: "select", proxies: allProxies.length > 0 ? [ "Balance", ...allProxies] : ["DIRECT"], icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Proxy.png" };

  const Global = { name: "Global", type: "select", proxies: G, icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Global.png" };
  // 国内网站
  const Mainland = { name: "Mainland", type: "select", proxies: M, icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Round_Robin.png" };
  // 人工智能
  const ArtIntel = { name: "ArtIntel", type: "select", proxies: AI, icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Copilot.png" };
  // 油管视频
  const YouTube = { name: "YouTube", type: "select", proxies: G, icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/YouTube.png" };
  // 哔哩哔哩
  const BiliBili = { name: "BiliBili", type: "select", proxies: ["DIRECT", "HongKong", "TaiWan"], icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/bilibili.png" };
  // 国际媒体
  const Streaming = { name: "Streaming", type: "select", proxies: G, icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/ForeignMedia.png" };
  // 电报信息
  const Telegram = { name: "Telegram", type: "select", proxies: G, icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Telegram.png" };
  // 谷歌服务
  const Google = { name: "Google", type: "select", proxies: G, icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Google.png" };
  // 游戏平台
  const Games = { name: "Games", type: "select", proxies: G, icon: "https://fastly.jsdelivr.net/gh/Koolson/Qure/IconSet/Color/Game.png" };
  // 插入分组
  const groups = params["proxy-groups"] = [];
  groups.unshift(HongKong, TaiWan, Japan, Singapore, America, Others, Auto, Balance, Fallback);
  groups.unshift(Final, Proxy, Global, Mainland, ArtIntel, YouTube, BiliBili, Streaming, Telegram, Google, Games);

  // 规则
  const rules = [
    "AND,(AND,(DST-PORT,443),(NETWORK,UDP)),(NOT,((GEOIP,CN,no-resolve))),REJECT",// quic
    "PROCESS-NAME,tor.real,Global",
    "PROCESS-NAME,tor,Global",
    "PROCESS-NAME,lyrebird,Global",
    "DOMAIN-SUFFIX,+.local,DIRECT",
    "DOMAIN-SUFFIX,awesome-hd.me,DIRECT",
    "DOMAIN-SUFFIX,broadcasthe.net,DIRECT",
    "DOMAIN-SUFFIX,chdbits.co,DIRECT",
    "DOMAIN-SUFFIX,classix-unlimited.co.uk,DIRECT",
    "DOMAIN-SUFFIX,empornium.me,DIRECT",
    "DOMAIN-SUFFIX,gazellegames.net,DIRECT",
    "DOMAIN-SUFFIX,hdchina.org,DIRECT",
    "DOMAIN-SUFFIX,hdsky.me,DIRECT",
    "DOMAIN-SUFFIX,icetorrent.org,DIRECT",
    "DOMAIN-SUFFIX,jpopsuki.eu,DIRECT",
    "DOMAIN-SUFFIX,keepfrds.com,DIRECT",
    "DOMAIN-SUFFIX,madsrevolution.net,DIRECT",
    "DOMAIN-SUFFIX,m-team.cc,DIRECT",
    "DOMAIN-SUFFIX,nanyangpt.com,DIRECT",
    "DOMAIN-SUFFIX,ncore.cc,DIRECT",
    "DOMAIN-SUFFIX,open.cd,DIRECT",
    "DOMAIN-SUFFIX,ourbits.club,DIRECT",
    "DOMAIN-SUFFIX,passthepopcorn.me,DIRECT",
    "DOMAIN-SUFFIX,privatehd.to,DIRECT",
    "DOMAIN-SUFFIX,redacted.ch,DIRECT",
    "DOMAIN-SUFFIX,springsunday.net,DIRECT",
    "DOMAIN-SUFFIX,tjupt.org,DIRECT",
    "DOMAIN-SUFFIX,totheglory.im,DIRECT",
    "DOMAIN-SUFFIX,smtp,DIRECT",
    "DOMAIN-SUFFIX,cube.weixinbridge.com,DIRECT",
    "DOMAIN-KEYWORD,announce,DIRECT",
    "DOMAIN-KEYWORD,torrent,DIRECT",
    "DOMAIN-KEYWORD,tracker,DIRECT",
    "DOMAIN,clash.razord.top,DIRECT",
    "DOMAIN,d.metacubex.one,DIRECT",
    "DOMAIN,yacd.haishan.me,DIRECT",
    "DOMAIN,clash.razord.top,DIRECT",
    "DOMAIN,yacd.metacubex.one,DIRECT",
    //"GEOSITE,Category-ads-all,REJECT",// 可能导致某些网站无法访问
    "GEOSITE,Private,DIRECT",
    "GEOSITE,Bing,ArtIntel",
    "GEOSITE,Openai,ArtIntel",
    "GEOSITE,Category-games@cn,Mainland",
    "GEOSITE,Category-games,Games",
    "GEOSITE,Github,Global",
    "GEOIP,Telegram,Telegram,no-resolve",
    "GEOSITE,Bilibili,BiliBili",
    "GEOSITE,Youtube,YouTube",
    "GEOSITE,Disney,Streaming",
    "GEOSITE,Netflix,Streaming",
    "GEOSITE,HBO,Streaming",
    "GEOSITE,Primevideo,Streaming",
    "GEOSITE,Google,Google",
    "GEOSITE,Microsoft@cn,Mainland",
    "GEOSITE,Apple@cn,Mainland",
    "GEOSITE,Geolocation-!cn,Global",
    "GEOSITE,CN,Mainland",
    "GEOIP,private,DIRECT,no-resolve",
    "GEOIP,Telegram,Telegram,no-resolve",
    "GEOIP,LAN,DIRECT,no-resolve",
    "GEOIP,CN,DIRECT,no-resolve",
    "MATCH,Final"
  ];

  const newDnsConfig =  {
  "dns": {
    "enable": true,
    "ipv6": false,
    "enhanced-mode": "redir-host",
    "listen": ":1053",
    "fake-ip-range": "198.18.0.1/16",
    "fake-ip-filter": ["*", "+.lan", "+.local", "+.msftncsi.com", "+.msftconnecttest.com"],
    "proxy-server-nameserver": ["https://dns.alidns.com/dns-query", "https://doh.pub/dns-query"],
    "nameserver-policy": {
      "geosite:cn,private": ["https://doh.pub/dns-query", "https://dns.alidns.com/dns-query"],
      "geosite:geolocation-!cn,gfw,Bing,Openai,Github,Youtube,Google": ["https://dns.cloudflare.com/dns-query#dns", "https://dns.google/dns-query#dns"]
    },
    "nameserver": ["https://doh.pub/dns-query", "https://dns.alidns.com/dns-query"],
    "fallback": ["tls://8.8.4.4", "tls://1.1.1.1"],
    "fallback-filter": {
      "geoip": true,
      "geoip-code": "CN",
      "ipcidr": ["240.0.0.0/4", "0.0.0.0/32"],
      "geosite": [
        "gfw",
        "Bing",
        "Openai",
        "Github",
        "Youtube",
        "Google",
        "Geolocation-!cn"
      ]
    }
  }
}


const additionalConfig = {
  "bind-address": '*',
  "mode": "rule",
  "redir-port": 7895,
  "mixed-port": 7890,
  "socks-port": 7898,
  "port": 7899,
  "allow-lan": true,
  "log-level": "silent",
  "ipv6": false,
  "secret": "password",
  "external-controller": "127.0.0.1:9090",
  "external-ui": "./ui",
  "unified-delay": false,
  "tcp-concurrent": true,
  "keep-alive-interval": 15,
  "skip-auth-prefixes": ['127.0.0.1/8', '::1/128'],
  "geodata-mode": true,
  "geox-url": {
    "geoip": "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geoip-lite.dat",
    "geosite": "https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat",
    "mmdb": "https://cdn.jsdelivr.net/gh/Hackl0us/GeoIP2-CN@release/Country.mmdb"
  },
  "geo-auto-update": true,
  "geo-update-interval": 24,
  "find-process-mode": "strict",
  "global-client-fingerprint": "chrome",
  "profile": {
    "store-selected": true,
    "store-fake-ip": true
  },
  "sniffer": {
    "enable": false,
    "parse-pure-ip": true,
    "sniff": {
      "HTTP": {
        "ports": [80, "8080-8880"],
        "override-destination": true
      },
      "TLS": {
        "ports": [443, 8443]
      },
      "QUIC": {
        "ports": [443, 8443]
      }
    },
    "force-domain": ['google.com'],
    "skip-domain": ['Mijia Cloud','dlg.io.mi.com','+.apple.com']
  },
  "tun": {
    "enable": true,
    "stack": "gvisor",
    "dns-hijack": ["any:53"],
    "strict-route": true,
    "auto-route": true,
    "auto-detect-interface": true,
    "inet4-route-exclude-address": ['192.168.0.0/16', '127.0.0.0/8','172.16.0.0/12','10.0.0.0/8','0.0.0.0/8']
  }
};


  for (let key in additionalConfig) {
    if (additionalConfig.hasOwnProperty(key)) {
      params[key] = additionalConfig[key];
    }
  }

  params.rules = rules;                                               
  params.dns = newDnsConfig.dns;  

  return params;
}

function getProxiesByRegex(params, regex) {
  return params.proxies
    .filter((e) => regex.test(e.name))
    .map((e) => e.name);
}
// 读取 old.yaml 文件
// const oldConfig = yaml.load(fs.readFileSync('/tmp/old.yaml', 'utf8'));

// 生成新的配置
// const newConfig = main(oldConfig);


// 写入 new.yaml 文件
// fs.writeFileSync('/tmp/config.yaml', yaml.dump(newConfig), 'utf8');

// console.log('新配置文件已生成: config.yaml');
