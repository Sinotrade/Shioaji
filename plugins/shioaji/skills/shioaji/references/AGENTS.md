# Agents / Agent 環境

Use this reference only when the user explicitly asks how to install the Shioaji plugin/skill in Claude, Codex, Cursor, or another agent environment. Do not use it for normal Shioaji onboarding, account opening, API keys, signing, Python install, or project setup.
只有在使用者明確詢問如何在 Claude、Codex、Cursor 或其他 agent 環境安裝 Shioaji plugin/skill 時才使用本文件。一般 Shioaji 入門、開戶、API 金鑰、簽署、Python 安裝或專案設定不要讀這份。

The current agent may already have this skill installed. These commands are for installing Shioaji into the **other** agent environment or explaining cross-agent availability; do not tell the user to reinstall the current active skill unless they explicitly ask.
目前 agent 可能已經安裝此 skill。下面指令是用來安裝到**另一種** agent 環境,或說明跨 agent 可用性;除非使用者明確要求,不要叫使用者重新安裝目前正在使用的 skill。

## Claude

```bash
claude plugin marketplace add Sinotrade/Shioaji
claude plugin install shioaji
```

## Codex

Search for **Shioaji** in the Codex Marketplace to install it, or use the CLI:

在 Codex 的 Marketplace 中搜尋 **Shioaji** 即可安裝，或使用指令：

```bash
codex plugin marketplace add Sinotrade/Shioaji
codex plugin add shioaji@sinotrade
```

## Cursor

Search for **Shioaji** in the Cursor Marketplace and click **Get** to install.

在 Cursor 的 Marketplace 中搜尋 **Shioaji**，點選 **Get** 即可安裝。
