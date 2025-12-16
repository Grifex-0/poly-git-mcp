// Bitbucket API adapter
// Provides tools for managing Bitbucket repositories via HTTP API

open Deno

type toolDef = {
  name: string,
  description: string,
  inputSchema: JSON.t,
}

// Bitbucket uses app passwords or OAuth. We'll use app password auth.
// Set BITBUCKET_USERNAME and BITBUCKET_APP_PASSWORD environment variables

let baseUrl = ref("https://api.bitbucket.org/2.0")
let username = ref("")
let appPassword = ref("")

let init = () => {
  username := Env.getWithDefault("BITBUCKET_USERNAME", "")
  appPassword := Env.getWithDefault("BITBUCKET_APP_PASSWORD", "")
}

let authHeaders = (): dict<string> => {
  let auth = btoa(`${username.contents}:${appPassword.contents}`)
  Dict.fromArray([
    ("Authorization", `Basic ${auth}`),
    ("Content-Type", "application/json"),
  ])
}

let fetchApi = async (path: string): result<string, string> => {
  init()
  let headers = authHeaders()
  let result = await Fetch.get(`${baseUrl.contents}${path}`, ~headers)
  switch result {
  | Ok(json) => Ok(JSON.stringify(json))
  | Error(e) => Error(e)
  }
}

let tools: dict<toolDef> = Dict.fromArray([
  ("bb_repo_list", {
    name: "bb_repo_list",
    description: "List Bitbucket repositories",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "workspace": { "type": "string", "description": "Workspace slug" },
        "role": { "type": "string", "enum": ["owner", "admin", "contributor", "member"], "description": "Filter by role" }
      }
    }`),
  }),
  ("bb_repo_view", {
    name: "bb_repo_view",
    description: "View repository details",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "workspace": { "type": "string", "description": "Workspace slug" },
        "repo": { "type": "string", "description": "Repository slug" }
      },
      "required": ["workspace", "repo"]
    }`),
  }),
  ("bb_issue_list", {
    name: "bb_issue_list",
    description: "List issues (requires issue tracker enabled)",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "workspace": { "type": "string", "description": "Workspace slug" },
        "repo": { "type": "string", "description": "Repository slug" },
        "state": { "type": "string", "enum": ["new", "open", "resolved", "on hold", "invalid", "duplicate", "wontfix", "closed"], "description": "Issue state" }
      },
      "required": ["workspace", "repo"]
    }`),
  }),
  ("bb_pr_list", {
    name: "bb_pr_list",
    description: "List pull requests",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "workspace": { "type": "string", "description": "Workspace slug" },
        "repo": { "type": "string", "description": "Repository slug" },
        "state": { "type": "string", "enum": ["OPEN", "MERGED", "DECLINED", "SUPERSEDED"], "description": "PR state" }
      },
      "required": ["workspace", "repo"]
    }`),
  }),
  ("bb_pr_view", {
    name: "bb_pr_view",
    description: "View a pull request",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "workspace": { "type": "string", "description": "Workspace slug" },
        "repo": { "type": "string", "description": "Repository slug" },
        "id": { "type": "integer", "description": "Pull request ID" }
      },
      "required": ["workspace", "repo", "id"]
    }`),
  }),
  ("bb_pipeline_list", {
    name: "bb_pipeline_list",
    description: "List pipelines",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "workspace": { "type": "string", "description": "Workspace slug" },
        "repo": { "type": "string", "description": "Repository slug" }
      },
      "required": ["workspace", "repo"]
    }`),
  }),
  ("bb_branches", {
    name: "bb_branches",
    description: "List branches",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "workspace": { "type": "string", "description": "Workspace slug" },
        "repo": { "type": "string", "description": "Repository slug" }
      },
      "required": ["workspace", "repo"]
    }`),
  }),
  ("bb_commits", {
    name: "bb_commits",
    description: "List recent commits",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "workspace": { "type": "string", "description": "Workspace slug" },
        "repo": { "type": "string", "description": "Repository slug" },
        "branch": { "type": "string", "description": "Branch name (optional)" }
      },
      "required": ["workspace", "repo"]
    }`),
  }),
  ("bb_workspaces", {
    name: "bb_workspaces",
    description: "List workspaces for authenticated user",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {}
    }`),
  }),
  ("bb_user", {
    name: "bb_user",
    description: "Get current user info",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {}
    }`),
  }),
])

let handleToolCall = async (name: string, args: JSON.t): result<string, string> => {
  let argsDict = args->JSON.Decode.object->Option.getOr(Dict.make())
  let getString = key => argsDict->Dict.get(key)->Option.flatMap(JSON.Decode.string)->Option.getOr("")
  let getInt = key => argsDict->Dict.get(key)->Option.flatMap(JSON.Decode.float)->Option.map(v => Int.fromFloat(v))

  let workspace = getString("workspace")
  let repo = getString("repo")

  switch name {
  | "bb_repo_list" => {
      let role = getString("role")
      let path = workspace !== ""
        ? `/repositories/${workspace}`
        : `/repositories`
      let path = role !== "" ? `${path}?role=${role}` : path
      await fetchApi(path)
    }
  | "bb_repo_view" => await fetchApi(`/repositories/${workspace}/${repo}`)
  | "bb_issue_list" => {
      let state = getString("state")
      let path = `/repositories/${workspace}/${repo}/issues`
      let path = state !== "" ? `${path}?q=state="${state}"` : path
      await fetchApi(path)
    }
  | "bb_pr_list" => {
      let state = getString("state")
      let path = `/repositories/${workspace}/${repo}/pullrequests`
      let path = state !== "" ? `${path}?state=${state}` : path
      await fetchApi(path)
    }
  | "bb_pr_view" => {
      let id = getInt("id")->Option.getOr(0)
      await fetchApi(`/repositories/${workspace}/${repo}/pullrequests/${Int.toString(id)}`)
    }
  | "bb_pipeline_list" => await fetchApi(`/repositories/${workspace}/${repo}/pipelines/`)
  | "bb_branches" => await fetchApi(`/repositories/${workspace}/${repo}/refs/branches`)
  | "bb_commits" => {
      let branch = getString("branch")
      let path = `/repositories/${workspace}/${repo}/commits`
      let path = branch !== "" ? `${path}/${branch}` : path
      await fetchApi(path)
    }
  | "bb_workspaces" => await fetchApi("/workspaces")
  | "bb_user" => await fetchApi("/user")
  | _ => Error("Unknown tool: " ++ name)
  }
}
