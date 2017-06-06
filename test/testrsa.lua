local skynet = require "skynet"
local crypt = require "skynet.crypt"


local src = "hello world !"

local privpem = [[-----BEGIN PRIVATE KEY-----
MIICeAIBADANBgkqhkiG9w0BAQEFAASCAmIwggJeAgEAAoGBANMfFz1aPEuvl/AN
0lVNXoMGoRrUPfmHtKtUfpaM7vxPXtYzHsBzu6KLOBDeOjXO9YD43vLIRpZwO0r4
kWLMYGSZMxSQba7itQ5H6kDc2dm7UQqsJ34wupejGADd2iEOBappvXH7LEaGhjvs
W1ZOZi1r5or0HXqRNkWIGvU8YYWpAgMBAAECgYA+wMcPnXq+pHrtB661XEHzgEzy
xJOHUCcLphnadhmzNYRi9t71JXFoZylLGkMDK3kd1NuwHoecv89gAXJ1g3pC4mW+
D9xZluFre2qlYs+nn0nE1cNJ+ogqkjQ76XuV/9IuZSSPCxRJ6W4EaR3rQi/ORK/o
KOKucP4kFTJTMQrwYQJBAO6xYGrfiRSQkQKj0dR2at29t5gRJ5FU6XzVsy1WAN3G
goSqOVBYCAL2IF8jHbt5dvX1QKzAKX44vBSmCs6/B5sCQQDibe68z4WKFOYGbg75
ZKmmJuCzDCTRaZu4ThpqFVJlwdw1JeFOX3r+4qpwfNDOSOinzL7BmO+sHBBmBUJG
jLYLAkEA7ZFFcZmCiiFI8uOx2FD0FDbbIFMSmqd0rHbVmu3aduE4zmnOGZVEhA4M
MiR1Vz6RlEPBVy77HVHCgJqybwvauQJBAJQ9WKFwU4MVL4tiHpeUGaVXqqBOAQTA
2VwOdiihkPJhuuNoy1reE84vY1qFvMZw4TCKURC6KZ9KOEoygzNhCAUCQQDsOp9u
EL2lf9pph/xpdMlIk4s1f6cJ19YTOq/F9Bdk6Ilok23yuuynDnV31LLG1wEscn/n
jyiiuJjC1pbr+LLV
-----END PRIVATE KEY-----]]


local pubpem = [[-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDTHxc9WjxLr5fwDdJVTV6DBqEa
1D35h7SrVH6WjO78T17WMx7Ac7uiizgQ3jo1zvWA+N7yyEaWcDtK+JFizGBkmTMU
kG2u4rUOR+pA3NnZu1EKrCd+MLqXoxgA3dohDgWqab1x+yxGhoY77FtWTmYta+aK
9B16kTZFiBr1PGGFqQIDAQAB
-----END PUBLIC KEY-----]]


skynet.start(function()
    local bs = crypt.rsaprisign(src, privpem)
    local sign = crypt.base64encode(bs)
    print("----- RSA SIGN TEST -----")
    print(sign)
    local dbs = crypt.base64decode(sign)
    local ok = crypt.rsapubverify(src, dbs, pubpem, 2)
    assert(ok)
    print("----- RSA SIGN TEST OK -----\n")

    print("----- RSA CRYPT TEST -----")
    bs = crypt.rsapubenc(src, pubpem, 2)
    local dst = crypt.base64encode(bs)
    print(dst)
    dbs = crypt.base64decode(dst)
    local dsrc = crypt.rsapridec(dbs, privpem)
    print(dsrc)
    assert(dsrc == src)
    print("----- RSA CRYPT TEST OK -----\n")
    skynet.exit()
end)