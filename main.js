#!/usr/bin/env -S deno run --allow-run --allow-read --allow-env --allow-net
// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

// poly-git-mcp - Git forge MCP server
// Adapters: GitHub (gh), GitLab (glab), Gitea (tea), Bitbucket (API)

import * as GitHub from "./lib/es6/src/adapters/GitHub.res.js";
import * as GitLab from "./lib/es6/src/adapters/GitLab.res.js";
import * as Gitea from "./lib/es6/src/adapters/Gitea.res.js";
import * as Bitbucket from "./lib/es6/src/adapters/Bitbucket.res.js";

const SERVER_INFO = {
  name: "poly-git-mcp",
  version: "1.0.0",
  description: "Git forge MCP server (GitHub, GitLab, Gitea, Bitbucket)",
};

// Combine all tools from adapters
const allTools = {
  ...GitHub.tools,
  ...GitLab.tools,
  ...Gitea.tools,
  ...Bitbucket.tools,
};

// Route tool calls to appropriate adapter
async function handleToolCall(name, args) {
  if (name.startsWith("gh_")) {
    return await GitHub.handleToolCall(name, args);
  } else if (name.startsWith("glab_")) {
    return await GitLab.handleToolCall(name, args);
  } else if (name.startsWith("tea_")) {
    return await Gitea.handleToolCall(name, args);
  } else if (name.startsWith("bb_")) {
    return await Bitbucket.handleToolCall(name, args);
  }
  return { TAG: "Error", _0: `Unknown tool: ${name}` };
}

// MCP Protocol handlers
function handleInitialize(id) {
  return {
    jsonrpc: "2.0",
    id,
    result: {
      protocolVersion: "2024-11-05",
      serverInfo: SERVER_INFO,
      capabilities: {
        tools: { listChanged: false },
      },
    },
  };
}

function handleToolsList(id) {
  const toolsList = Object.values(allTools).map((tool) => ({
    name: tool.name,
    description: tool.description,
    inputSchema: tool.inputSchema,
  }));

  return {
    jsonrpc: "2.0",
    id,
    result: { tools: toolsList },
  };
}

async function handleToolsCall(id, params) {
  const { name, arguments: args } = params;
  const result = await handleToolCall(name, args || {});

  if (result.TAG === "Ok") {
    return {
      jsonrpc: "2.0",
      id,
      result: {
        content: [{ type: "text", text: result._0 }],
      },
    };
  } else {
    return {
      jsonrpc: "2.0",
      id,
      result: {
        content: [{ type: "text", text: `Error: ${result._0}` }],
        isError: true,
      },
    };
  }
}

// Main message handler
async function handleMessage(message) {
  const { method, id, params } = message;

  switch (method) {
    case "initialize":
      return handleInitialize(id);
    case "initialized":
      return null;
    case "tools/list":
      return handleToolsList(id);
    case "tools/call":
      return await handleToolsCall(id, params);
    default:
      return {
        jsonrpc: "2.0",
        id,
        error: { code: -32601, message: `Method not found: ${method}` },
      };
  }
}

// stdio transport
const decoder = new TextDecoder();
const encoder = new TextEncoder();

async function readMessage() {
  const buffer = new Uint8Array(65536);
  let data = "";

  while (true) {
    const n = await Deno.stdin.read(buffer);
    if (n === null) return null;

    data += decoder.decode(buffer.subarray(0, n));

    const headerEnd = data.indexOf("\r\n\r\n");
    if (headerEnd === -1) continue;

    const header = data.substring(0, headerEnd);
    const contentLengthMatch = header.match(/Content-Length: (\d+)/i);
    if (!contentLengthMatch) continue;

    const contentLength = parseInt(contentLengthMatch[1]);
    const bodyStart = headerEnd + 4;
    const bodyEnd = bodyStart + contentLength;

    if (data.length < bodyEnd) continue;

    const body = data.substring(bodyStart, bodyEnd);
    data = data.substring(bodyEnd);

    return JSON.parse(body);
  }
}

function writeMessage(message) {
  const body = JSON.stringify(message);
  const header = `Content-Length: ${encoder.encode(body).length}\r\n\r\n`;
  Deno.stdout.writeSync(encoder.encode(header + body));
}

async function main() {
  while (true) {
    const message = await readMessage();
    if (message === null) break;

    const response = await handleMessage(message);
    if (response !== null) {
      writeMessage(response);
    }
  }
}

main().catch(console.error);
