# Trust self-signed certs
function set-trustallcerts {
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

# given a user and corresponding API key, connect and obtain token
function connect-conjur {
    param (
        [Parameter()] [String] $conjurhost,
        [Parameter()] [String] $account,
        [Parameter()] [String] $apikey,
        [Parameter()] [String] $user
    )
    
    $url = "https://$conjurhost/authn/$account/$user/authenticate"
    
    # using invoke-webrequest to get raw data back
    $response = Invoke-WebRequest -Method POST -Uri $url -body $apikey -ContentType "application/json" -UseBasicParsing
    
    # convert raw token data to base64
    $token = Out-String -InputObject $response.content
    $b = [System.Text.Encoding]::UTF8.GetBytes($token) 
    $token = [System.Convert]::ToBase64String($b)

    return $token
}

# pull conjur secret using token
function get-conjursecret {
    param (
        [Parameter()] [String] $conjurhost,
        [Parameter()] [String] $account,
        [Parameter()] [String] $token,
        [Parameter()] [String] $obj
    )
    # build token string to include double quotes as they are needed
    $tokenString = 'Token token="' + $token + '"'

    $header = @{ }
    $header.Add("Authorization", "$tokenString")
    
    $url = "https://$conjurhost/secrets/$account/variable/$obj"

    $response = Invoke-restmethod -Method GET -Uri $url -header $header -ContentType "application/json" -UseBasicParsing

    return $response
}

# Ensure self-signed certs are trusted
try {
    set-trustallcerts
    }
catch {
    # ignore if error
}

# specify conjur host address (and port if not 443)
$conjurhost = "localhost:8443"

# specify account
$account = "myConjurAccount"

# specify user for account that has access to object with API key
$user = "host%2FBotApp%2FmyDemoApp"
$apikey = "244pcqz3xs9k9212k1b821bm66mbwkf7ey3961pnw3ex8ca824xwcmh"



# request API token
try {
    $token = connect-conjur $conjurhost $account $apikey $user -ErrorAction Stop
} 
catch {
    $errormsg = $_.Exception.Message
    write-host "WARNING: Token request failed. Error: $errormsg"
}


# specify secret
$obj = "BotApp%2FsecretVar"

# use token to pull secret
try {
    $secret = get-conjursecret $conjurhost $account $token $obj -ErrorAction Stop
    write-output "Pulled secret ""$obj"" from Conjur: $secret"
}
catch  {
    $errormsg = $_.Exception.Message
    write-host "WARNING: Secret request failed. Error: $errormsg"
}
