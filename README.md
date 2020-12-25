DevOps-Monitor-Microservice
============================

[![](https://imgedu.lagou.com/680719-20200325165435510-655432212.png)](#DevOps-Monitor-Microservice)


## Description

We used the **Prometheus** **+** **Grafana** to monitor our microservice resources usages.

---

> Monitoring services reference: <br />
  1. [**Grafana** + **Prometheus**](https://blog.51cto.com/kaliarch/2160569) <br />
  2. [**Grafana** + **Prometheus**](https://tpu.thinkpower.com.tw/tpu/articleDetails/992) <br />
  3. [Metric server](https://aeric.io/post/k8s-metrics-server-installation/) <br />
  4. [Metric server](https://blog.tianfeiyu.com/2019/04/14/k8s_metrics_server/)

---

## Version
`Rev: 1.0.7`

---

## Usage

  - Node exporter from docker


    ```bash
    $ docker run -d \
                 -p 9100:9100 \
                 -v /proc:/host/proc:ro \
                 -v /sys:/host/sys:ro \
                 -v /:/rootfs:ro \
                 --name ${container_name} \
                 --restart=always \
                 registry.ipt-gitlab:8081/sit-develop-tool/ipt-microservice-monitoring/node-exporter:1.0.2 \
                 --collector.filesystem.ignored-mount-points '"^/(sys|proc|dev|host|etc)($|/)"'
    ```

  - Monitoring `etcd` metrics

    - kubernetes `etcd` ssl certificate

      ```bash
      $ kubectl -n kube-monitor create secret generic etcd-certs --from-file=/etc/etcd/pki/ca.pem --from-file=/etc/etcd/pki/server.pem --from-file=/etc/etcd/pki/server-key.pem
      ```

    - Edit prometheus configmaps

      ```yml
      - job_name: 'kubernetes-etcd'
      scheme: https
      tls_config:
        ca_file: /var/run/secrets/kubernetes.io/k8s-certs/etcd/ca.pem
        cert_file: /var/run/secrets/kubernetes.io/k8s-certs/etcd/server.pem
        key_file: /var/run/secrets/kubernetes.io/k8s-certs/etcd/server-key.pem
      metrics_path: /metrics
      static_configs:
      - targets: ['10.99.104.214:2379','10.99.104.219:2379','10.99.104.241:2379']
      ```

    - Edit prometheus deploy Yaml

      ```yml

        - mountPath: "/var/run/secrets/kubernetes.io/k8s-certs/etcd/"
          name: k8s-certs

      .....
      .....
      .....

      serviceAccountName: prometheus
      volumes:
      - name: data
        emptyDir: {}
      - name: config-volume
        configMap:
          name: prometheus-config
      - name: k8s-certs
        secret:
          secretName: etcd-certs
      imagePullSecrets:
      - name: gitlab-registry
      terminationGracePeriodSeconds: 20
      ```


  - Metric service

    ```bash
    $ kubectl apply -f ./monitor/metrics .
    $ kubectl top nodes
    $ kubectl top pods -A
    ```

---

## TroubleShooting

  - if encountered following error:

    ```bash
    $ kubectl logs -f -n kube-system metrics-server-xxx

    E1003 05:46:13.757009       1 manager.go:102] unable to fully collect metrics: [unable to fully scrape metrics from source kubelet_summary:node1: unable to fetch metrics from Kubelet node1 (node1): Get https://k8s-node1:10250/stats/summary/: dial tcp: lookup k8s-node1 on 10.96.0.10:53: no such host, unable to fully scrape metrics from source kubelet_summary:k8s-node2: unable to fetch metrics from Kubelet node2 (node2): Get https://k8s-node2:10250/stats/summary/: dial tcp: lookup node2 on 10.96.0.10:53: read udp 10.244.1.6:45288->10.96.0.10:53: i/o timeout]
    ```

    - Method 1

      ```bash
      $ kubectl edit configmap coredns -n kube-system

      health
      hosts {          # Add this line
          $IP1  k8s-m1
          $IP2  k8s-node1
          $IP3  k8s-node2
          fallthrough
      }
      ```

    - Method 2

      ```bash
      $ vim ./monitor/metrics/metrics-server-deployment.yaml
      ```

      ```yaml
      containers:
      - name: metrics-server
        image: registry.ipt-gitlab:8081/sit-develop-tool/ipt-microservice-monitoring/metrics-server:__VERSION__
        command:
         - /metrics-server
         - --metric-resolution=30s
         - --kubelet-insecure-tls
         - --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP
        args: [ "--kubelet-insecure-tls" ]
        imagePullPolicy: Always
        volumeMounts:
        - name: tmp-dir
          mountPath: /tmp
      imagePullSecrets:
      - name: gitlab-registry

      ```

---

## Associates

  - **Developer**
    - Chang.Jay

---

## Contact
##### Author: Jay.Chang
##### Email: cqe5914678@gmail.com
