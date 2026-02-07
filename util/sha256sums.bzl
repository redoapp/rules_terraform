def sha256sums_parse(string):
    result = {}
    for line in string.splitlines():
        digest, path = line.split("  ")
        result[path] = digest
    return result
