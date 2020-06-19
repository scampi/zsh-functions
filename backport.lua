local argparse = require "argparse"
local colors = require 'ansicolors'

local parser = argparse()
	:name "backport"
	:description "Backport commits to a branch."
parser:argument("branch", "The branch name to backport commits to.")
parser:argument("issue", "The issue number to reference.")
parser:option("-r --range", "A commit range."):args(2):count("*")
parser:option("-c --commit", "A single commit."):args(1):count("*")

local args = parser:parse()

function execute(command)
	local _, _, code = os.execute(command)
	if code ~= 0 then
		print(colors('%{red}something has gone wrong!'))
		os.exit(1)
	end
end

-- get the current branch name: https://stackoverflow.com/a/11868440
local handle = io.popen('git rev-parse --abbrev-ref HEAD')
local original_branch = handle:read("*a")
handle:close()

local staging_branch = 'BP-branch-' .. args.branch .. '-' .. args.issue
local commits = ""
for k, v in pairs(args.range) do
	commits = commits .. " " .. v[1] .. "~1.." .. v[2]
end
for k, v in ipairs(args.commit) do
	commits = commits .. " " .. v
end
local pr_body='backport #' .. args.issue .. ' to branch-' .. args.branch .. '\n\nIssue #' .. args.issue

print(colors('%{green}checkout branch branch-' .. args.branch .. ' to backport'))
execute('git checkout branch-' .. args.branch)

print(colors('%{green}update the branch'))
execute('git pull')

print(colors('%{green}create branch ' .. staging_branch .. ' for the commits to backport'))
os.execute('git checkout -b ' .. staging_branch)
local _, _, code = os.execute('git cherry-pick -x ' .. commits)
while code ~= 0 do
	execute('git mergetool')
	_, _, code = os.execute('git cherry-pick --continue')
end

print(colors('%{green}check the branch compiles with the new changes'))
local _, _, code = os.execute('mvn clean test-compile compile')
if code ~= 0 then
	print(colors('%{red}something has gone wrong!'))
	print(colors('%{red}fix then create PR with: hub pull-request -m "' .. pr_body .. '" -b branch-' .. args.branch))
	os.exit(1)
end

print(colors('%{green}push the new branch'))
execute('git push origin ' .. staging_branch)

print(colors('%{green}create the pull request'))
execute('hub pull-request -m "' .. pr_body .. '" -b branch-' .. args.branch)

os.execute('git checkout ' .. original_branch)
