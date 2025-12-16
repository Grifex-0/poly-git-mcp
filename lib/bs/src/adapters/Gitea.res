// Gitea CLI adapter
// Provides tools for managing Gitea repositories via tea cli

open Deno

type toolDef = {
  name: string,
  description: string,
  inputSchema: JSON.t,
}

let runTea = async (args: array<string>): result<string, string> => {
  let cmd = Command.new("tea", ~args=Array.concat(args, ["--output", "simple"]))
  let output = await Command.output(cmd)
  if output.success {
    Ok(Command.stdoutText(output))
  } else {
    Error(Command.stderrText(output))
  }
}

let tools: dict<toolDef> = Dict.fromArray([
  ("tea_repo_list", {
    name: "tea_repo_list",
    description: "List Gitea repositories",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "owner": { "type": "string", "description": "Owner (user or org)" },
        "starred": { "type": "boolean", "description": "List starred repos" },
        "limit": { "type": "integer", "description": "Max repos to list" }
      }
    }`),
  }),
  ("tea_repo_view", {
    name: "tea_repo_view",
    description: "View repository details",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" }
      },
      "required": ["repo"]
    }`),
  }),
  ("tea_issue_list", {
    name: "tea_issue_list",
    description: "List issues",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "state": { "type": "string", "enum": ["open", "closed", "all"], "description": "Issue state" },
        "kind": { "type": "string", "enum": ["issue", "pull"], "description": "Issue kind" }
      }
    }`),
  }),
  ("tea_issue_view", {
    name: "tea_issue_view",
    description: "View an issue",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository" },
        "number": { "type": "integer", "description": "Issue number" }
      },
      "required": ["number"]
    }`),
  }),
  ("tea_issue_create", {
    name: "tea_issue_create",
    description: "Create an issue",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository" },
        "title": { "type": "string", "description": "Issue title" },
        "description": { "type": "string", "description": "Issue body" }
      },
      "required": ["title"]
    }`),
  }),
  ("tea_pr_list", {
    name: "tea_pr_list",
    description: "List pull requests",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository" },
        "state": { "type": "string", "enum": ["open", "closed", "all"], "description": "PR state" }
      }
    }`),
  }),
  ("tea_pr_view", {
    name: "tea_pr_view",
    description: "View a pull request",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository" },
        "number": { "type": "integer", "description": "PR number" }
      },
      "required": ["number"]
    }`),
  }),
  ("tea_pr_create", {
    name: "tea_pr_create",
    description: "Create a pull request",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository" },
        "title": { "type": "string", "description": "PR title" },
        "description": { "type": "string", "description": "PR description" },
        "head": { "type": "string", "description": "Head branch" },
        "base": { "type": "string", "description": "Base branch" }
      },
      "required": ["title", "head", "base"]
    }`),
  }),
  ("tea_release_list", {
    name: "tea_release_list",
    description: "List releases",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository" }
      }
    }`),
  }),
  ("tea_org_list", {
    name: "tea_org_list",
    description: "List organizations",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {}
    }`),
  }),
  ("tea_login_list", {
    name: "tea_login_list",
    description: "List configured Gitea logins",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {}
    }`),
  }),
])

let handleToolCall = async (name: string, args: JSON.t): result<string, string> => {
  let argsDict = args->JSON.Decode.object->Option.getOr(Dict.make())
  let getString = key => argsDict->Dict.get(key)->Option.flatMap(JSON.Decode.string)->Option.getOr("")
  let getBool = key => argsDict->Dict.get(key)->Option.flatMap(JSON.Decode.bool)->Option.getOr(false)
  let getInt = key => argsDict->Dict.get(key)->Option.flatMap(JSON.Decode.float)->Option.map(v => Int.fromFloat(v))

  let repo = getString("repo")
  let repoArg = repo !== "" ? ["-r", repo] : []

  switch name {
  | "tea_repo_list" => {
      let owner = getString("owner")
      let starred = getBool("starred")
      let limit = getInt("limit")

      let args = ["repos", "ls"]
      let args = owner !== "" ? Array.concat(args, ["-o", owner]) : args
      let args = starred ? Array.concat(args, ["--starred"]) : args
      let args = switch limit { | Some(n) => Array.concat(args, ["-l", Int.toString(n)]) | None => args }
      await runTea(args)
    }
  | "tea_repo_view" => await runTea(Array.concat(["repos", "view"], repoArg))
  | "tea_issue_list" => {
      let state = getString("state")
      let kind = getString("kind")

      let args = ["issues", "ls"]
      let args = Array.concat(args, repoArg)
      let args = state !== "" ? Array.concat(args, ["-s", state]) : args
      let args = kind !== "" ? Array.concat(args, ["-k", kind]) : args
      await runTea(args)
    }
  | "tea_issue_view" => {
      let number = getInt("number")->Option.getOr(0)
      await runTea(Array.concat(["issues", "view", Int.toString(number)], repoArg))
    }
  | "tea_issue_create" => {
      let title = getString("title")
      let description = getString("description")

      let args = ["issues", "create", "-t", title]
      let args = Array.concat(args, repoArg)
      let args = description !== "" ? Array.concat(args, ["-d", description]) : args
      await runTea(args)
    }
  | "tea_pr_list" => {
      let state = getString("state")
      let args = ["pulls", "ls"]
      let args = Array.concat(args, repoArg)
      let args = state !== "" ? Array.concat(args, ["-s", state]) : args
      await runTea(args)
    }
  | "tea_pr_view" => {
      let number = getInt("number")->Option.getOr(0)
      await runTea(Array.concat(["pulls", "view", Int.toString(number)], repoArg))
    }
  | "tea_pr_create" => {
      let title = getString("title")
      let description = getString("description")
      let head = getString("head")
      let base = getString("base")

      let args = ["pulls", "create", "-t", title, "-H", head, "-B", base]
      let args = Array.concat(args, repoArg)
      let args = description !== "" ? Array.concat(args, ["-d", description]) : args
      await runTea(args)
    }
  | "tea_release_list" => await runTea(Array.concat(["releases", "ls"], repoArg))
  | "tea_org_list" => await runTea(["orgs", "ls"])
  | "tea_login_list" => await runTea(["logins", "ls"])
  | _ => Error("Unknown tool: " ++ name)
  }
}
