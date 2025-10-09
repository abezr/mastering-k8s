@abezr ➜ /workspaces/mastering-k8s (main) $ ./setup.sh kind
[INFO] Detected environment: codespaces
Setting up Kubernetes control plane for AMD64...
[INFO] Setting up Kind cluster for testing...
[INFO] Downloading Kind...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    97  100    97    0     0    312      0 --:--:-- --:--:-- --:--:--   311
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 9697k  100 9697k    0     0  16.4M      0 --:--:-- --:--:-- --:--:-- 16.4M
[INFO] Creating Kind cluster...
Creating cluster "codespaces-test-cluster" ...
 ✓ Ensuring node image (kindest/node:v1.31.0) 🖼 
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-codespaces-test-cluster"
You can now use your cluster with:

kubectl cluster-info --context kind-codespaces-test-cluster

Not sure what to do next? 😅  Check out https://kind.sigs.k8s.io/docs/user/quick-start/
[SUCCESS] Kind cluster created successfully
@abezr ➜ /workspaces/mastering-k8s (main) $ ./setup.sh deploy
[INFO] Detected environment: codespaces
Setting up Kubernetes control plane for AMD64...
[INFO] Setting up Kind cluster for testing...
[INFO] Downloading Kind...
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    97  100    97    0     0   1821      0 --:--:-- --:--:-- --:--:--  1830
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100 9697k  100 9697k    0     0  46.3M      0 --:--:-- --:--:-- --:--:-- 46.3M
[INFO] Creating Kind cluster...
ERROR: failed to create cluster: node(s) already exist for a cluster with the name "codespaces-test-cluster"
@abezr ➜ /workspaces/mastering-k8s (main) $ ./setup.sh test
[INFO] Detected environment: codespaces
Setting up Kubernetes control plane for AMD64...
[INFO] Testing controller deployment...
[SUCCESS] Controller pod is running
[WARNING] CRDs not found
[INFO] Deployment status:
@abezr ➜ /workspaces/mastering-k8s (main) $ 