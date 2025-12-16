// GitHub CLI adapter
// Provides tools for managing GitHub repositories, issues, PRs via gh cli

open Deno

type toolDef = {
  name: string,
  description: string,
  inputSchema: JSON.t,
}

let runGh = async (args: array<string>): result<string, string> => {
  let cmd = Command.new("gh", ~args)
  let output = await Command.output(cmd)
  if output.success {
    Ok(Command.stdoutText(output))
  } else {
    Error(Command.stderrText(output))
  }
}

let tools: dict<toolDef> = Dict.fromArray([
  ("gh_repo_list", {
    name: "gh_repo_list",
    description: "List GitHub repositories",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "owner": { "type": "string", "description": "Owner (user or org)" },
        "limit": { "type": "integer", "description": "Max repos to list" },
        "visibility": { "type": "string", "enum": ["public", "private", "internal"], "description": "Filter by visibility" }
      }
    }`),
  }),
  ("gh_repo_view", {
    name: "gh_repo_view",
    description: "View repository details",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" }
      },
      "required": ["repo"]
    }`),
  }),
  ("gh_repo_clone", {
    name: "gh_repo_clone",
    description: "Clone a repository",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo or URL)" },
        "directory": { "type": "string", "description": "Target directory" }
      },
      "required": ["repo"]
    }`),
  }),
  ("gh_issue_list", {
    name: "gh_issue_list",
    description: "List issues in a repository",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "state": { "type": "string", "enum": ["open", "closed", "all"], "description": "Issue state" },
        "label": { "type": "string", "description": "Filter by label" },
        "assignee": { "type": "string", "description": "Filter by assignee" },
        "limit": { "type": "integer", "description": "Max issues to list" }
      }
    }`),
  }),
  ("gh_issue_view", {
    name: "gh_issue_view",
    description: "View an issue",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "number": { "type": "integer", "description": "Issue number" }
      },
      "required": ["number"]
    }`),
  }),
  ("gh_issue_create", {
    name: "gh_issue_create",
    description: "Create a new issue",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "title": { "type": "string", "description": "Issue title" },
        "body": { "type": "string", "description": "Issue body" },
        "labels": { "type": "array", "items": { "type": "string" }, "description": "Labels to add" },
        "assignees": { "type": "array", "items": { "type": "string" }, "description": "Assignees" }
      },
      "required": ["title"]
    }`),
  }),
  ("gh_pr_list", {
    name: "gh_pr_list",
    description: "List pull requests",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "state": { "type": "string", "enum": ["open", "closed", "merged", "all"], "description": "PR state" },
        "base": { "type": "string", "description": "Base branch" },
        "head": { "type": "string", "description": "Head branch" },
        "limit": { "type": "integer", "description": "Max PRs to list" }
      }
    }`),
  }),
  ("gh_pr_view", {
    name: "gh_pr_view",
    description: "View a pull request",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "number": { "type": "integer", "description": "PR number" }
      },
      "required": ["number"]
    }`),
  }),
  ("gh_pr_create", {
    name: "gh_pr_create",
    description: "Create a pull request",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "title": { "type": "string", "description": "PR title" },
        "body": { "type": "string", "description": "PR body" },
        "base": { "type": "string", "description": "Base branch" },
        "head": { "type": "string", "description": "Head branch" },
        "draft": { "type": "boolean", "description": "Create as draft" }
      },
      "required": ["title"]
    }`),
  }),
  ("gh_pr_merge", {
    name: "gh_pr_merge",
    description: "Merge a pull request",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "number": { "type": "integer", "description": "PR number" },
        "method": { "type": "string", "enum": ["merge", "squash", "rebase"], "description": "Merge method" },
        "delete": { "type": "boolean", "description": "Delete branch after merge" }
      },
      "required": ["number"]
    }`),
  }),
  ("gh_release_list", {
    name: "gh_release_list",
    description: "List releases",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "limit": { "type": "integer", "description": "Max releases to list" }
      }
    }`),
  }),
  ("gh_workflow_list", {
    name: "gh_workflow_list",
    description: "List workflow runs",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Repository (owner/repo)" },
        "workflow": { "type": "string", "description": "Workflow name or ID" },
        "limit": { "type": "integer", "description": "Max runs to list" }
      }
    }`),
  }),
  ("gh_auth_status", {
    name: "gh_auth_status",
    description: "Check authentication status",
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
  let getArray = key => argsDict->Dict.get(key)->Option.flatMap(JSON.Decode.array)->Option.getOr([])

  let repo = getString("repo")
  let repoArg = repo !== "" ? ["-R", repo] : []

  switch name {
  | "gh_repo_list" => {
      let owner = getString("owner")
      let limit = getInt("limit")
      let visibility = getString("visibility")

      let args = ["repo", "list"]
      let args = owner !== "" ? Array.concat(args, [owner]) : args
      let args = switch limit { | Some(n) => Array.concat(args, ["-L", Int.toString(n)]) | None => args }
      let args = visibility !== "" ? Array.concat(args, ["--visibility", visibility]) : args
      await runGh(Array.concat(args, ["--json", "name,description,url,visibility"]))
    }
  | "gh_repo_view" => await runGh(Array.concat(["repo", "view"], Array.concat(repoArg, ["--json", "name,description,url,stargazerCount,forkCount"])))
  | "gh_repo_clone" => {
      let directory = getString("directory")
      let args = ["repo", "clone", repo]
      let args = directory !== "" ? Array.concat(args, [directory]) : args
      await runGh(args)
    }
  | "gh_issue_list" => {
      let state = getString("state")
      let label = getString("label")
      let assignee = getString("assignee")
      let limit = getInt("limit")

      let args = ["issue", "list"]
      let args = Array.concat(args, repoArg)
      let args = state !== "" ? Array.concat(args, ["-s", state]) : args
      let args = label !== "" ? Array.concat(args, ["-l", label]) : args
      let args = assignee !== "" ? Array.concat(args, ["-a", assignee]) : args
      let args = switch limit { | Some(n) => Array.concat(args, ["-L", Int.toString(n)]) | None => args }
      await runGh(Array.concat(args, ["--json", "number,title,state,author,labels"]))
    }
  | "gh_issue_view" => {
      let number = getInt("number")->Option.getOr(0)
      await runGh(Array.concat(["issue", "view", Int.toString(number)], Array.concat(repoArg, ["--json", "number,title,body,state,author,labels,comments"])))
    }
  | "gh_issue_create" => {
      let title = getString("title")
      let body = getString("body")
      let labels = getArray("labels")->Array.filterMap(JSON.Decode.string)
      let assignees = getArray("assignees")->Array.filterMap(JSON.Decode.string)

      let args = ["issue", "create", "-t", title]
      let args = Array.concat(args, repoArg)
      let args = body !== "" ? Array.concat(args, ["-b", body]) : args
      let args = labels->Array.length > 0 ? Array.concat(args, ["-l", labels->Array.join(",")]) : args
      let args = assignees->Array.length > 0 ? Array.concat(args, ["-a", assignees->Array.join(",")]) : args
      await runGh(args)
    }
  | "gh_pr_list" => {
      let state = getString("state")
      let base = getString("base")
      let head = getString("head")
      let limit = getInt("limit")

      let args = ["pr", "list"]
      let args = Array.concat(args, repoArg)
      let args = state !== "" ? Array.concat(args, ["-s", state]) : args
      let args = base !== "" ? Array.concat(args, ["-B", base]) : args
      let args = head !== "" ? Array.concat(args, ["-H", head]) : args
      let args = switch limit { | Some(n) => Array.concat(args, ["-L", Int.toString(n)]) | None => args }
      await runGh(Array.concat(args, ["--json", "number,title,state,author,baseRefName,headRefName"]))
    }
  | "gh_pr_view" => {
      let number = getInt("number")->Option.getOr(0)
      await runGh(Array.concat(["pr", "view", Int.toString(number)], Array.concat(repoArg, ["--json", "number,title,body,state,author,baseRefName,headRefName,reviews"])))
    }
  | "gh_pr_create" => {
      let title = getString("title")
      let body = getString("body")
      let base = getString("base")
      let head = getString("head")
      let draft = getBool("draft")

      let args = ["pr", "create", "-t", title]
      let args = Array.concat(args, repoArg)
      let args = body !== "" ? Array.concat(args, ["-b", body]) : args
      let args = base !== "" ? Array.concat(args, ["-B", base]) : args
      let args = head !== "" ? Array.concat(args, ["-H", head]) : args
      let args = draft ? Array.concat(args, ["--draft"]) : args
      await runGh(args)
    }
  | "gh_pr_merge" => {
      let number = getInt("number")->Option.getOr(0)
      let mergeMethod = getString("method")
      let deleteBranch = getBool("delete")

      let args = ["pr", "merge", Int.toString(number)]
      let args = Array.concat(args, repoArg)
      let args = switch mergeMethod {
      | "squash" => Array.concat(args, ["--squash"])
      | "rebase" => Array.concat(args, ["--rebase"])
      | _ => Array.concat(args, ["--merge"])
      }
      let args = deleteBranch ? Array.concat(args, ["--delete-branch"]) : args
      await runGh(args)
    }
  | "gh_release_list" => {
      let limit = getInt("limit")
      let args = ["release", "list"]
      let args = Array.concat(args, repoArg)
      let args = switch limit { | Some(n) => Array.concat(args, ["-L", Int.toString(n)]) | None => args }
      await runGh(args)
    }
  | "gh_workflow_list" => {
      let workflow = getString("workflow")
      let limit = getInt("limit")

      let args = ["run", "list"]
      let args = Array.concat(args, repoArg)
      let args = workflow !== "" ? Array.concat(args, ["-w", workflow]) : args
      let args = switch limit { | Some(n) => Array.concat(args, ["-L", Int.toString(n)]) | None => args }
      await runGh(Array.concat(args, ["--json", "databaseId,displayTitle,status,conclusion,createdAt"]))
    }
  | "gh_auth_status" => await runGh(["auth", "status"])
  | _ => Error("Unknown tool: " ++ name)
  }
}
