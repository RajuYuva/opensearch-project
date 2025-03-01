# opensearch-project
Opensearch cluster using operator
# **Deploying OpenSearch Using OpenSearch Operator in AWS EKS**

This document covers the step-by-step deployment of OpenSearch inside an **AWS EKS** cluster using the **OpenSearch Operator**, troubleshooting encountered issues, and the final configuration ensuring a successful deployment.

---

## **1. Setting Up Kubernetes Environment**

### **1.1 Provision EKS Cluster**
- Used **Amazon EKS** as the Kubernetes cluster (used terraform eks module and applied the configuration using terraform apply).
- Verified that the cluster is running:
  ```sh
  kubectl get nodes
  ```
- Ensured `kubectl` is configured to interact with the EKS cluster:
  ```sh
  aws eks update-kubeconfig --name <eks-cluster-name> --region <aws-region>
  ```

---

## **2. Installing OpenSearch Operator**

### **2.1 Deploying servica account**
The OpenSearch Operator requires **service account**. installed them using:

```sh
kubectl apply -f serviceaccount.yaml
```

### **2.2 Deploying Operator CRDs**
The OpenSearch Operator requires **Custom Resource Definitions (CRDs)**. We installed them using:

```sh
kubectl apply -f opensearch-operator-crds.yaml
```
Checking installed CRDs:
```sh
ubuntu@ip-172-31-86-72:~$ kubectl get crds | grep opensearch
opensearchactiongroups.opensearch.opster.io         2025-03-01T11:54:47Z
opensearchclusters.opensearch.opster.io             2025-03-01T12:22:45Z
opensearchcomponenttemplates.opensearch.opster.io   2025-03-01T11:54:47Z
opensearchindextemplates.opensearch.opster.io       2025-03-01T11:54:47Z
opensearchismpolicies.opensearch.opster.io          2025-03-01T11:54:47Z
opensearchroles.opensearch.opster.io                2025-03-01T11:54:47Z
opensearchtenants.opensearch.opster.io              2025-03-01T11:54:47Z
opensearchuserrolebindings.opensearch.opster.io     2025-03-01T11:54:47Z
opensearchusers.opensearch.opster.io                2025-03-01T11:54:47Z
```
### **2.3 Creating Service Account & RBAC Permissions**
To allow the **Operator to manage OpenSearch resources**, we created:

#### **ClusterRole for OpenSearch Operator**
```yaml
kubectl apply -f opensearch-operator-clusterrole.yaml
```

#### **ClusterRoleBinding for OpenSearch Operator**
```yaml
kubectl apply -f opensearch-operator-binding.yaml
```

### **2.4 Deploying the OpenSearch Operator**
We applied the **Operator Deployment**:

```sh
kubectl apply -f operator-deployment.yaml
```

Then, verified its status:
```sh
kubectl get pods -n opensearch
NAME                                   READY   STATUS    RESTARTS   AGE
opensearch-operator-56c7cdc79d-hjb2t   1/1     Running   0          3h53m
```

---

## **3. Deploying OpenSearch Cluster**

### **3.1 Applying OpenSearchCluster Resource**
We deployed OpenSearch using the **Operator-managed custom resource**:

```yaml
apiVersion: opensearch.opster.io/v1
kind: OpenSearchCluster
metadata:
  name: opensearch-cluster
  namespace: opensearch
spec:
  general:
    serviceName: opensearch-cluster
    version: 2.7.0
  nodePools:
    - component: nodes
      replicas: 3
      roles:
        - cluster_manager
        - data
      resources:
        requests:
          cpu: "500m"
          memory: "2Gi"
        limits:
          cpu: "1000m"
          memory: "4Gi"
      diskSize: "20Gi"
      persistence:
        storageClass: gp2
        accessModes:
          - ReadWriteOnce
  dashboards:
    enable: true
    version: 2.9.0
    replicas: 1
    tls:
      enable: true
      generate: true
    resources:
      requests:
        cpu: "200m"
        memory: "512Mi"
      limits:
        cpu: "500m"
        memory: "1Gi"
  security:
    config:
      securityConfigSecret:
        name: ""
    tls:
      transport:
        generate: true
        perNode: true
```

Applied it using:
```sh
kubectl apply -f opensearch-cluster.yaml
```

Checked for statefulset creation:
```sh
kubectl get statefulsets -n opensearch
```

---

## **4. Troubleshooting Operator & Cluster Issues**

### **4.1 Issue: Operator Not Creating StatefulSets, PVCs, or Services**
- We checked operator logs:
  ```sh
  kubectl logs -n opensearch deployment/opensearch-operator
  ```
- Found **reconciliation errors** where OpenSearchCluster was stuck and did not create StatefulSets.

#### **Manual Fix: Created StatefulSet for OpenSearch**
Since the operator failed, we **manually created a StatefulSet**:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: opensearch-cluster
  namespace: opensearch
spec:
  serviceName: "opensearch-cluster"
  replicas: 3
  selector:
    matchLabels:
      app: opensearch
  template:
    metadata:
      labels:
        app: opensearch
    spec:
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: opensearch
        image: opensearchproject/opensearch:2.7.0
        ports:
        - containerPort: 9200
        volumeMounts:
        - name: opensearch-config
          mountPath: /usr/share/opensearch/config/opensearch.yml
          subPath: opensearch.yml
        - name: opensearch-storage
          mountPath: /usr/share/opensearch/data
      volumes:
      - name: opensearch-config
        configMap:
          name: opensearch-config
  volumeClaimTemplates:
  - metadata:
      name: opensearch-storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 20Gi
      storageClassName: gp2
```

Applied it:
```sh
kubectl apply -f opensearch-statefulset.yaml
```

---

## **5. Fixing Persistent Volume Issues**

### **5.1 Issue: OpenSearch Pods Failing Due to Storage (PVC Not Bound)**
- **PVCs were not created by the Operator.**
- The cluster needed **EBS CSI drivers** for volume management.

### **5.2 Solution: Installed EBS CSI Drivers**
We installed the **Amazon EBS CSI Driver**:

```sh
eksctl create addon --name aws-ebs-csi-driver --cluster <eks-cluster-name> --region <aws-region>
```

### **5.3 Created EBS CSI Controller Service Account**
```sh
eksctl create iamserviceaccount --name ebs-csi-controller-sa --namespace kube-system \
  --cluster <eks-cluster-name> --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve
```

### **5.4 Updated EKS Node IAM Role with Volume Permissions**
```sh
aws iam attach-role-policy --role-name <eks-node-role-name> --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
```

### **5.5 Restarted StatefulSet**
```sh
kubectl rollout restart statefulset opensearch-cluster -n opensearch
```
After this, the **pods started running successfully**.

```sh
kubectl get pods -n opensearch
NAME                                   READY   STATUS    RESTARTS   AGE
opensearch-cluster-0                   1/1     Running   0          135m
opensearch-cluster-1                   1/1     Running   0          136m
opensearch-cluster-2                   1/1     Running   0          136m
opensearch-operator-56c7cdc79d-hjb2t   1/1     Running   0          3h53m
```

---

## **6. Verifying OpenSearch Cluster**

Opensearch cluster:
```sh
kubectl get opensearchclusters -n opensearch
NAME                 AGE
opensearch-cluster   4h2m
```
Statefulset:
```sh
kubectl get statefulsets -n opensearch
NAME                 READY   AGE
opensearch-cluster   3/3     165m
```
Pvc:
```sh
kubectl get pvc -n opensearch
NAME                                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
opensearch-storage-opensearch-cluster-0   Bound    pvc-7bd5667b-3659-47ce-8596-ab39903d785c   20Gi       RWO            gp2            167m
opensearch-storage-opensearch-cluster-1   Bound    pvc-be508e3f-c068-4ba1-85a0-c634d1b45a30   20Gi       RWO            gp2            167m
opensearch-storage-opensearch-cluster-2   Bound    pvc-0140b8fe-4687-4fca-89a7-bedf118a7027   20Gi       RWO            gp2            167m
```
Service:
```sh
kubectl get svc -n opensearch
NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
opensearch-cluster    ClusterIP   None            <none>        9200/TCP,9300/TCP   149m
```
Checking service:
```sh
kubectl port-forward svc/opensearch-cluster 9200:9200 -n opensearch
Forwarding from 127.0.0.1:9200 -> 9200
Forwarding from [::1]:9200 -> 9200
```
Open another terminal and check the connection and cluster health:
```sh
ubuntu@ip-172-31-86-72:~$ curl -k -X GET "http://localhost:9200/_cluster/health?pretty"
{
  "cluster_name" : "opensearch-cluster",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 3,
  "discovered_master" : true,
  "discovered_cluster_manager" : true,
  "active_primary_shards" : 1,
  "active_shards" : 3,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}
```

Checked node status:
```sh
ubuntu@ip-172-31-86-72:~$ kubectl exec -it opensearch-cluster-0 -n opensearch -- curl -k -X GET "http://localhost:9200/_cat/nodes?v"
ip            heap.percent ram.percent cpu load_1m load_5m load_15m node.role node.roles                                        cluster_manager name
172.31.6.12             11          21   0    0.13    0.16     0.08 dimr      cluster_manager,data,ingest,remote_cluster_client -               opensearch-cluster-0
172.31.8.169            47          21   0    0.13    0.16     0.08 dimr      cluster_manager,data,ingest,remote_cluster_client -               opensearch-cluster-2
172.31.89.172           31          21   0    0.00    0.05     0.04 dimr      cluster_manager,data,ingest,remote_cluster_client *               opensearch-cluster-1
```

---

## **Final Deliverables**

✅ **Terraform Code**: EKS Cluster, IAM Roles, and OpenSearch Deployment.  
✅ **OpenSearch Operator-Based Deployment**  
✅ **Cluster Security Best Practices**  
✅ **README with Validation Steps**  

---

**Cleanup**:
```sh
kubectl delete -f opensearch-cluster.yaml -n opensearch
kubectl delete -f operator-deployment.yaml -n opensearch
kubectl delete -f opensearch-operator-crds.yaml -n opensearch
kubectl delete -f opensearch-operator-binding.yaml -n opensearch
kubectl delete -f opensearch-operator-clusterrole.yaml -n opensearch
kubectl delete -f opensearch-service.yaml -n opensearch
kubectl delete -f opensearch-pv.yaml -n opensearch
kubectl delete -f opensearch-statefulset.yaml -n opensearch
kubectl delete -f serviceaccount.yaml -n opensearch
terraform destroy
```
## **Final Deliverables**

✅ **Terraform Code**: EKS Cluster, IAM Roles, and OpenSearch Deployment.\
✅ **OpenSearch Operator-Based Deployment**\
✅ **Cluster Security Best Practices**\
✅ **README with Validation Steps**

---
