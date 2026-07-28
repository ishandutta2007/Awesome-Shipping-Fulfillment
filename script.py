import re
import urllib.request
import json
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def get_stars(repo_url):
    match = re.search(r'github\.com/([^/]+/[^/]+?)(?:/|$)', repo_url)
    if not match:
        return -1, ""
    repo_path = match.group(1).rstrip('/')
    url = f"https://api.github.com/repos/{repo_path}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req, context=ctx) as response:
            data = json.loads(response.read().decode())
            return data.get('stargazers_count', 0), repo_path
    except Exception as e:
        print(f"Error fetching {repo_path}: {e}")
        return 0, repo_path

with open('README.md', 'r', encoding='utf-8') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if line.startswith("## Open-Source GitHub Projects"):
        start_idx = i
    if start_idx != -1 and line.startswith("### Additional Strong Open-Source Options"):
        end_idx = i
        break

section_lines = lines[start_idx+1:end_idx]

# Parse items
items = []
current_item = []
for line in section_lines:
    if line.strip().startswith("- **["):
        if current_item:
            items.append("".join(current_item))
        current_item = [line]
    elif current_item:
        current_item.append(line)

if current_item:
    items.append("".join(current_item))

parsed_items = []
for item in items:
    match = re.match(r'- \*\*\[(.*?)\]\((.*?)\)\*\*(.*)', item, re.DOTALL)
    if match:
        name, url, rest = match.groups()
        stars, repo_path = get_stars(url)
        if stars >= 0:
            badge = f'[![GitHub stars](https://img.shields.io/github/stars/{repo_path}?style=social&color=white)](https://github.com/{repo_path}/stargazers)'
            new_item = f'- **[{name}]({url})** {badge}{rest}'
            parsed_items.append((stars, new_item))
        else:
            parsed_items.append((-1, item))
    else:
        parsed_items.append((-1, item))

# Sort parsed_items by stars descending
parsed_items.sort(key=lambda x: x[0], reverse=True)

# Build the new section
new_section_lines = ["\n"]
for stars, item in parsed_items:
    new_section_lines.append(item)
    if not item.endswith('\n'):
        new_section_lines.append('\n')

lines = lines[:start_idx+1] + new_section_lines + ["\n"] + lines[end_idx:]

with open('README.md', 'w', encoding='utf-8') as f:
    f.writelines(lines)
