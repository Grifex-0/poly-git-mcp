// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

/// Deno runtime bindings for poly-git-mcp

module Env = {
  @scope(("Deno", "env")) @val
  external get: string => option<string> = "get"

  let getWithDefault = (key: string, default: string): string => {
    switch get(key) {
    | Some(v) => v
    | None => default
    }
  }
}

@scope("Deno") @val
external writeTextFile: (string, string) => promise<unit> = "writeTextFile"

@scope("Deno") @val
external readTextFile: (string) => promise<string> = "readTextFile"

module Command = {
  type t

  type commandOutput = {
    success: bool,
    code: int,
    stdout: Js.TypedArray2.Uint8Array.t,
    stderr: Js.TypedArray2.Uint8Array.t,
  }

  @new external textDecoder: unit => {"decode": Js.TypedArray2.Uint8Array.t => string} = "TextDecoder"

  let decoder = textDecoder()

  let stdoutText = (output: commandOutput): string => decoder["decode"](output.stdout)
  let stderrText = (output: commandOutput): string => decoder["decode"](output.stderr)

  type commandInit = {
    args?: array<string>,
    cwd?: string,
    stdout?: string,
    stderr?: string,
  }

  @new @scope("Deno")
  external makeCommand: (string, commandInit) => t = "Command"

  @send external output: t => promise<commandOutput> = "output"

  let new = (cmd: string, ~args: array<string>=[], ~cwd: string=""): t => {
    if cwd !== "" {
      makeCommand(cmd, {args, cwd, stdout: "piped", stderr: "piped"})
    } else {
      makeCommand(cmd, {args, stdout: "piped", stderr: "piped"})
    }
  }

  let run = async (binary: string, args: array<string>): (int, string, string) => {
    let cmd = new(binary, ~args)
    let result = await output(cmd)
    (result.code, stdoutText(result), stderrText(result))
  }
}

// Base64 encoding
@val external btoa: string => string = "btoa"
@val external atob: string => string = "atob"

module Fetch = {
  type response = {
    ok: bool,
    status: int,
    statusText: string,
  }

  type requestInit = {
    method: string,
    headers?: dict<string>,
    body?: string,
  }

  @val external fetch: (string, requestInit) => promise<response> = "fetch"
  @send external text: response => promise<string> = "text"
  @send external json: response => promise<JSON.t> = "json"

  let get = async (url: string, ~headers: dict<string>=Dict.make()): result<JSON.t, string> => {
    try {
      let response = await fetch(url, {method: "GET", headers})
      if response.ok {
        let data = await json(response)
        Ok(data)
      } else {
        Error(`HTTP ${Int.toString(response.status)}: ${response.statusText}`)
      }
    } catch {
    | Exn.Error(e) => Error(Exn.message(e)->Option.getOr("Unknown error"))
    }
  }

  let post = async (url: string, ~body: string, ~headers: dict<string>=Dict.make()): result<JSON.t, string> => {
    try {
      let response = await fetch(url, {method: "POST", headers, body})
      if response.ok {
        let data = await json(response)
        Ok(data)
      } else {
        Error(`HTTP ${Int.toString(response.status)}: ${response.statusText}`)
      }
    } catch {
    | Exn.Error(e) => Error(Exn.message(e)->Option.getOr("Unknown error"))
    }
  }

  let delete = async (url: string, ~headers: dict<string>=Dict.make()): result<JSON.t, string> => {
    try {
      let response = await fetch(url, {method: "DELETE", headers})
      if response.ok {
        Ok(JSON.Encode.object(Dict.fromArray([("success", JSON.Encode.bool(true))])))
      } else {
        Error(`HTTP ${Int.toString(response.status)}: ${response.statusText}`)
      }
    } catch {
    | Exn.Error(e) => Error(Exn.message(e)->Option.getOr("Unknown error"))
    }
  }
}
