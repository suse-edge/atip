import yaml
import os

# -----------------------------
# Configurable paths
# -----------------------------
RELEASE_FILE = "release-3.2.0.yaml"  # Path to your release manifest
ROOT_PATH = "../"                      # Root directory to scan recursively for .yaml files

# -----------------------------
# YAML Dumper with preserved indentation
# -----------------------------
class IndentedDumper(yaml.SafeDumper):
    def increase_indent(self, flow=False, indentless=False):
        return super(IndentedDumper, self).increase_indent(flow, False)

# -----------------------------
# Load release manifest
# -----------------------------
with open(RELEASE_FILE) as f:
    release = yaml.safe_load(f)

# Extract versions from the release manifest
release_versions = {}
helm_charts = release.get("spec", {}).get("components", {}).get("workloads", {}).get("helm", [])

for chart in helm_charts:
    release_versions[chart["releaseName"]] = chart["version"]
    for dep in chart.get("dependencyCharts", []):
        release_versions[dep["releaseName"]] = dep["version"]
    for addon in chart.get("addonCharts", []):
        release_versions[addon["releaseName"]] = addon["version"]

# Kubernetes version (from rke2)
k8s_version = release.get("spec", {}).get("components", {}).get("kubernetes", {}).get("rke2", {}).get("version")
release_versions["__k8s_version__"] = k8s_version

# -----------------------------
# Update logic
# -----------------------------
def update_versions_in_mgmt_file(mgmt, release_versions):
    # Update Kubernetes version
    if "kubernetes" in mgmt and "version" in mgmt["kubernetes"]:
        mgmt["kubernetes"]["version"] = release_versions.get("__k8s_version__", mgmt["kubernetes"]["version"])

    # Update Helm chart versions
    charts = mgmt.get("kubernetes", {}).get("helm", {}).get("charts", [])
    for chart in charts:
        name = chart.get("name")
        if name in release_versions:
            chart["version"] = release_versions[name]

    return mgmt

def process_yaml_file(filepath, release_versions):
    with open(filepath) as f:
        try:
            data = yaml.safe_load(f)
        except yaml.YAMLError:
            print(f"Warning: Failed to parse YAML file {filepath}, skipping.")
            return False

    if not data or "kubernetes" not in data:
        return False

    print(f"Updating versions in: {filepath}")
    updated_data = update_versions_in_mgmt_file(data, release_versions)

    with open(filepath, "w") as f:
        yaml.dump(
            updated_data,
            f,
            Dumper=IndentedDumper,
            default_flow_style=False,
            sort_keys=False,
            indent=2,
            width=4096,
        )

    return True

# -----------------------------
# Recursively walk through ROOT_PATH
# -----------------------------
for root, dirs, files in os.walk(ROOT_PATH):
    for file in files:
        if file.endswith(".yaml"):
            full_path = os.path.join(root, file)
            process_yaml_file(full_path, release_versions)
