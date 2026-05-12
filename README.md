I will preface this task with my lack of experience or comfort in developing on my personal machine. I am generally operating in enterprise environments with resources made available by design. 
Prior to starting this task, my local environment was partially configured from running the startup task found at: https://repo1.dso.mil/big-bang/bigbang/-/blob/master/docs/installation/environments/quick-start.md#access-a-big-bang-service
From that, I had preexisting downloads of Docker, kubectl, helm, curl, wget, tar, gzip, git, and jq.
Following that, I followed vendor documentation to download the remaining dependencies to my WSL environment.


##Summary recap:
following the aforementioned previous task, I continued the paradigm of running inside WSL Ubuntu.
I created my repo in github, using github actions for my CI tool
I chose sidecar injection because it was easier to troubleshoot and validate locally.