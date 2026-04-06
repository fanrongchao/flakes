# Tailscale + Mihomo / Clash Coexist Guide

> 这份文档现在只记录思路、边界和站点参数模型。
> 真正的配置真源是：
> 1. host 模块里的站点参数
> 2. `~/code/mihomocli` 生成出来的 Mihomo 配置
>
> 不再把 GUI 导出的 YAML 或旧 merge 模板当成真源。

---

## 目标态

- 本地目标运行态：`mode: rule`、`tun: true`、`sniffer: enabled`
- Tailscale 与 Mihomo 都可以长期打开
- Tailscale 相关流量从 Mihomo TUN 绕行
- 站点值由 host 配置或脚本参数提供，不写死在共享 profile 里

补充一个当前的本地现象：
- 这台 macOS 上当前 Codex desktop 会话仍然通过 Mihomo 的 `DEFAULT-MIXED` 入站访问外网
- 所以系统代理暂时保持开启并不代表 Tailscale/Clash 仍在打架
- 如果以后要继续追求“系统代理关闭也不断”，先看 controller 连接来自 `DEFAULT-MIXED` 还是 TUN，再决定改哪一层

---

## 站点参数

共享 profile 和脚本应当只依赖这些站点参数，而不是直接写死具体值：

```bash
export HEADSCALE_LOGIN_SERVER="https://hs.example.com"
export TAILNET_BASE_DOMAIN="tail.example.com"
export DERP_HOSTNAME="derp.example.com"
export DERP_IPV4="198.51.100.10"
```

当前 `ai-server` 站点实例只是一个 host-owned 例子：

```bash
HEADSCALE_LOGIN_SERVER="https://hs.zhsjf.cn"
TAILNET_BASE_DOMAIN="tail.zhsjf.cn"
DERP_HOSTNAME="derp.zhsjf.cn"
DERP_IPV4="218.11.1.14"
```

这些值现在应该只出现在 host 模块、部署参数或 operator 环境变量里。

---

## Repo 边界

### host 层负责站点值

- `services.zeroTrustControlPlane`
  - `serverUrl`
  - `tailnetBaseDomain`
  - `derp.hostname`
  - `derp.ipv4`
- `services.networkIngressProxy.virtualHosts`
- `services.ingressHaproxySni.tlsServerNames`
- `services.ingressHaproxySni.gitSshBackend`
- `services.mihomoEgress.mode`
- `services.mihomoEgress.snifferPreset`
- `services.mihomoEgress.tailscaleTailnetSuffixes`
- `services.mihomoEgress.tailscaleDirectDomains`
- `services.mihomoEgress.routeExcludeCidrs`
- `services.mihomoEgress.manualServerName`
- `services.mihomoEgress.manualServerAttachGroups`
- `services.mihomoEgress.customRules`

### 共享 profile 负责通用结构

- `zero-trust-control-plane.nix`
  - 生成 Headscale DERP map、共享控制面结构，以及 `headscale-derp-route-bypass`
- `network-ingress-proxy.nix`
  - 提供 Caddy ingress 框架，不绑定某一组域名
- `ingress-haproxy-sni.nix`
  - 提供多域名 SNI passthrough 框架，域名列表由 host 注入
- `network-egress-proxy.nix`
  - 提供 Mihomo egress 框架，不写死代理组名、手工节点名或 site-specific tailnet/DERP 值

这也是后面 HAProxy 继续接更多域名时的扩展方向：只改 host 的 `tlsServerNames` / `virtualHosts`，不要回去改共享 profile。

---

## mihomocli 边界

`mihomocli` 继续负责本地和 Linux 端的 Mihomo 配置生成，包括：

- `mode`
- `sniffer`
- fake-ip bypass
- Tailscale 相关 DIRECT/domain/CIDR 排除
- 对 Clash Verge controller 的 reload

但它不应该变成站点常量仓库。像这些值都应该作为参数传入：

- tailnet suffix
- Headscale 登录域名
- DERP 域名
- DERP IP / CIDR
- 需要 DIRECT 的额外域名

---

## 快速验证

### 控制面

```bash
curl --noproxy '*' "${HEADSCALE_LOGIN_SERVER}/health"
```

### DERP

```bash
curl -I "https://${DERP_HOSTNAME}/derp"
```

正常情况下会返回：

```text
426 DERP requires connection upgrade
```

### Tailscale

```bash
tailscale status
tailscale netcheck
tailscale debug derp 902
```

### 本地路由

```bash
netstat -rn | grep -E '100\\.64|utun'
route -n get "${DERP_IPV4}"
```

预期：
- `100.64.0.0/10` 走 Tailscale `utun`
- `${DERP_IPV4}` 走真实 uplink，不走 Mihomo TUN

### Mihomo 入站判断

如果以后再遇到“关系统代理就断”，先看 controller 里的连接来源：

- `sourceIP = 127.0.0.1`
- `inboundName = DEFAULT-MIXED`

这说明当前应用还在走本地代理，不是透明 TUN。

---

## 当前结论

- 本地这套现在能稳定做到 `Tailscale + Mihomo` 共存
- 规则模式仍然是目标态，shared profile 已经朝这个方向收敛
- `ai-server` 上解决 DERP/STUN 回包被 Mihomo UDP 劫持的 `headscale-derp-route-bypass` 仍然保留在共享控制面 profile
- 当前 Codex desktop 会话仍然依赖系统代理，这是应用入站路径问题，不再是 Tailscale/Clash 站点参数冲突
- 以后再换 DERP 域名、Headscale 域名、HAProxy 域名列表或代理组名，优先改 host 参数或 CLI 参数，不改共享 profile
