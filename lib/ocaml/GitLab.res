// GitLab CLI adapter
// Provides tools for managing GitLab projects, issues, MRs via glab cli

open Deno

type toolDef = {
  name: string,
  description: string,
  inputSchema: JSON.t,
}

let runGlab = async (args: array<string>): result<string, string> => {
  let cmd = Command.new("glab", ~args)
  let output = await Command.output(cmd)
  if output.success {
    Ok(Command.stdoutText(output))
  } else {
    Error(Command.stderrText(output))
  }
}

let tools: dict<toolDef> = Dict.fromArray([
  ("glab_project_list", {
    name: "glab_project_list",
    description: "List GitLab projects",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "group": { "type": "string", "description": "Filter by group/namespace" },
        "mine": { "type": "boolean", "description": "List only my projects" },
        "starred": { "type": "boolean", "description": "List starred projects" }
      }
    }`),
  }),
  ("glab_project_view", {
    name: "glab_project_view",
    description: "View project details",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path (group/project)" }
      },
      "required": ["repo"]
    }`),
  }),
  ("glab_issue_list", {
    name: "glab_issue_list",
    description: "List issues",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path" },
        "state": { "type": "string", "enum": ["opened", "closed", "all"], "description": "Issue state" },
        "label": { "type": "string", "description": "Filter by label" },
        "assignee": { "type": "string", "description": "Filter by assignee" }
      }
    }`),
  }),
  ("glab_issue_view", {
    name: "glab_issue_view",
    description: "View an issue",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path" },
        "number": { "type": "integer", "description": "Issue IID" }
      },
      "required": ["number"]
    }`),
  }),
  ("glab_issue_create", {
    name: "glab_issue_create",
    description: "Create an issue",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path" },
        "title": { "type": "string", "description": "Issue title" },
        "description": { "type": "string", "description": "Issue description" },
        "labels": { "type": "array", "items": { "type": "string" }, "description": "Labels" },
        "assignees": { "type": "array", "items": { "type": "string" }, "description": "Assignees" }
      },
      "required": ["title"]
    }`),
  }),
  ("glab_mr_list", {
    name: "glab_mr_list",
    description: "List merge requests",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path" },
        "state": { "type": "string", "enum": ["opened", "closed", "merged", "all"], "description": "MR state" },
        "draft": { "type": "boolean", "description": "Filter by draft status" }
      }
    }`),
  }),
  ("glab_mr_view", {
    name: "glab_mr_view",
    description: "View a merge request",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path" },
        "number": { "type": "integer", "description": "MR IID" }
      },
      "required": ["number"]
    }`),
  }),
  ("glab_mr_create", {
    name: "glab_mr_create",
    description: "Create a merge request",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path" },
        "title": { "type": "string", "description": "MR title" },
        "description": { "type": "string", "description": "MR description" },
        "source": { "type": "string", "description": "Source branch" },
        "target": { "type": "string", "description": "Target branch" },
        "draft": { "type": "boolean", "description": "Create as draft" }
      },
      "required": ["title"]
    }`),
  }),
  ("glab_mr_merge", {
    name: "glab_mr_merge",
    description: "Merge a merge request",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path" },
        "number": { "type": "integer", "description": "MR IID" },
        "squash": { "type": "boolean", "description": "Squash commits" },
        "removeSource": { "type": "boolean", "description": "Remove source branch" }
      },
      "required": ["number"]
    }`),
  }),
  ("glab_pipeline_list", {
    name: "glab_pipeline_list",
    description: "List pipelines",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path" },
        "status": { "type": "string", "enum": ["running", "pending", "success", "failed", "canceled"], "description": "Filter by status" }
      }
    }`),
  }),
  ("glab_ci_status", {
    name: "glab_ci_status",
    description: "Show CI/CD status for current branch",
    inputSchema: %raw(`{
      "type": "object",
      "properties": {
        "repo": { "type": "string", "description": "Project path" },
        "branch": { "type": "string", "description": "Branch name" }
      }
    }`),
  }),
  ("glab_auth_status", {
    name: "glab_auth_status",
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
  | "glab_project_list" => {
      let group = getString("group")
      let mine = getBool("mine")
      let starred = getBool("starred")

      let args = ["repo", "list"]
      let args = group !== "" ? Array.concat(args, ["-g", group]) : args
      let args = mine ? Array.concat(args, ["--mine"]) : args
      let args = starred ? Array.concat(args, ["--starred"]) : args
      await runGlab(args)
    }
  | "glab_project_view" => await runGlab(Array.concat(["repo", "view"], repoArg))
  | "glab_issue_list" => {
      let state = getString("state")
      let label = getString("label")
      let assignee = getString("assignee")

      let args = ["issue", "list"]
      let args = Array.concat(args, repoArg)
      let args = state !== "" ? Array.concat(args, ["-s", state]) : args
      let args = label !== "" ? Array.concat(args, ["-l", label]) : args
      let args = assignee !== "" ? Array.concat(args, ["-a", assignee]) : args
      await runGlab(args)
    }
  | "glab_issue_view" => {
      let number = getInt("number")->Option.getOr(0)
      await runGlab(Array.concat(["issue", "view", Int.toString(number)], repoArg))
    }
  | "glab_issue_create" => {
      let title = getString("title")
      let description = getString("description")
      let labels = getArray("labels")->Array.filterMap(JSON.Decode.string)
      let assignees = getArray("assignees")->Array.filterMap(JSON.Decode.string)

      let args = ["issue", "create", "-t", title]
      let args = Array.concat(args, repoArg)
      let args = description !== "" ? Array.concat(args, ["-d", description]) : args
      let args = labels->Array.length > 0 ? Array.concat(args, ["-l", labels->Array.join(",")]) : args
      let args = assignees->Array.length > 0 ? Array.concat(args, ["-a", assignees->Array.join(",")]) : args
      await runGlab(args)
    }
  | "glab_mr_list" => {
      let state = getString("state")
      let draft = getBool("draft")

      let args = ["mr", "list"]
      let args = Array.concat(args, repoArg)
      let args = state !== "" ? Array.concat(args, ["-s", state]) : args
      let args = draft ? Array.concat(args, ["--draft"]) : args
      await runGlab(args)
    }
  | "glab_mr_view" => {
      let number = getInt("number")->Option.getOr(0)
      await runGlab(Array.concat(["mr", "view", Int.toString(number)], repoArg))
    }
  | "glab_mr_create" => {
      let title = getString("title")
      let description = getString("description")
      let source = getString("source")
      let target = getString("target")
      let draft = getBool("draft")

      let args = ["mr", "create", "-t", title]
      let args = Array.concat(args, repoArg)
      let args = description !== "" ? Array.concat(args, ["-d", description]) : args
      let args = source !== "" ? Array.concat(args, ["-s", source]) : args
      let args = target !== "" ? Array.concat(args, ["-b", target]) : args
      let args = draft ? Array.concat(args, ["--draft"]) : args
      await runGlab(args)
    }
  | "glab_mr_merge" => {
      let number = getInt("number")->Option.getOr(0)
      let squash = getBool("squash")
      let removeSource = getBool("removeSource")

      let args = ["mr", "merge", Int.toString(number)]
      let args = Array.concat(args, repoArg)
      let args = squash ? Array.concat(args, ["--squash"]) : args
      let args = removeSource ? Array.concat(args, ["--remove-source-branch"]) : args
      await runGlab(args)
    }
  | "glab_pipeline_list" => {
      let status = getString("status")
      let args = ["pipeline", "list"]
      let args = Array.concat(args, repoArg)
      let args = status !== "" ? Array.concat(args, ["-s", status]) : args
      await runGlab(args)
    }
  | "glab_ci_status" => {
      let branch = getString("branch")
      let args = ["ci", "status"]
      let args = Array.concat(args, repoArg)
      let args = branch !== "" ? Array.concat(args, ["-b", branch]) : args
      await runGlab(args)
    }
  | "glab_auth_status" => await runGlab(["auth", "status"])
  | _ => Error("Unknown tool: " ++ name)
  }
}
