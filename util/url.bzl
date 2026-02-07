def url_resolve(base, url):
    if "://" in url:
        return url
    if url.startswith("//"):
        return base.split("//", 1)[0] + url
    if url.startswith("/"):
        return "/".join(base.split("/", 3)[0:3]) + url
    return base + url
