# Credentials For Registries And Git

The CI pipeline of the last part worked because every repository and the registry in the playground are open. A real pipeline pulls from private Git repositories, pushes images to a registry that wants a login, and pulls step images from private registries too. Each of these needs a credential, and each credential needs a safe way into the pod. Tekton has three of them: Secrets that a service account carries, Secrets that a workspace mounts, and image pull secrets. This part uses all three with made-up credentials, and shows how to keep the values out of logs.

## Three ways in

| Way | What it is for | Who reads the Secret |
| --- | --- | --- |
| Annotated Secret on the service account | Git and registry logins that tools find by themselves | Tekton, when it builds the pod |
| Secret as a workspace | A login file that a tool reads from a path, such as the Docker config of kaniko | The step, through a read-only mount |
| Image pull secret | Pulling the image of a step from a private registry | The kubelet of the node |

## Secrets on the service account

A Secret of type `kubernetes.io/basic-auth` or `kubernetes.io/ssh-auth` with an annotation tells Tekton which server it belongs to. The annotation key is `tekton.dev/git-0` for Git and `tekton.dev/docker-0` for registries, and its value is the server address. The service account of the run lists the Secret in `secrets`. When Tekton builds the pod of a TaskRun that uses this account, it prepares the credentials for the tools that read them from the home directory of the steps, so a plain `git` command authenticates without a flag.

<!-- astrona:playground:renew -->

Save this as `secret-gitea-login.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gitea-login
  namespace: starfleet
  annotations:
    tekton.dev/git-0: http://gitea-http.gitea.svc.cluster.local:3000
type: kubernetes.io/basic-auth
stringData:
  username: ci-bot
  password: not-a-real-password
```

Apply it and attach it to the service account `ci-bot` of the playground:

```sh
kubectl apply -f secret-gitea-login.yaml
kubectl patch serviceaccount ci-bot -n starfleet --type merge -p '{"secrets":[{"name":"gitea-login"}]}'
kubectl get serviceaccount ci-bot -n starfleet -o jsonpath='{.secrets[*].name}{"\n"}'
```

The last command lists `gitea-login`. Any TaskRun that runs as `ci-bot` can now use the login for that Git server. The annotation matters: without it, Tekton does not know which server the Secret is for and ignores it. The Secret type must match the use: `basic-auth` holds `username` and `password`, `ssh-auth` holds `ssh-privatekey`.

## A Secret as a workspace

Some tools do not read the home directory. kaniko looks for a Docker config file in the directory named by the environment variable `DOCKER_CONFIG`. A Secret of type `kubernetes.io/dockerconfigjson` has exactly that file under the key `.dockerconfigjson`. Mounted as a workspace, the key becomes a file.

Create the Secret from a made-up login:

```sh
kubectl create secret docker-registry registry-login -n starfleet \
  --docker-server=registry.registry.svc.cluster.local:5000 \
  --docker-username=ci --docker-password=not-a-real-password
```

Save this as `task-show-registry.yaml`. The Task prints which registry the login is for and never prints the password:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: show-registry
  namespace: starfleet
spec:
  workspaces:
    - name: dockerconfig
      readOnly: true
  steps:
    - name: show
      image: busybox:1.37.0
      env:
        - name: DOCKER_CONFIG
          value: $(workspaces.dockerconfig.path)
      script: |
        #!/bin/sh
        set -eu
        ls -a "$DOCKER_CONFIG"
        echo "registry in the login:"
        grep -o '"[a-z0-9.-]*:5000"' "$DOCKER_CONFIG/.dockerconfigjson"
```

Run it with the Secret bound to the workspace:

```sh
kubectl apply -f task-show-registry.yaml
tkn task start show-registry -n starfleet -w name=dockerconfig,secret=registry-login --showlog
```

The log lists the file `.dockerconfigjson` and prints the quoted registry address. The Secret was mounted read-only as a directory, as the workspace types of the earlier module say. For a real kaniko build, the file must be named `config.json`; a Secret created with `--from-file=config.json=...` gives that name, and `DOCKER_CONFIG` then points at the directory.

## Pulling step images from a private registry

The image of a step is pulled by the node, not by Tekton. The pod therefore needs `imagePullSecrets`. Two places can carry them: the service account (`imagePullSecrets` field) and the pod template of the run (`taskRunTemplate.podTemplate.imagePullSecrets`). A Secret in `secrets` of the service account is not used for pulling images; the field `imagePullSecrets` is.

## Keep values out of logs

A credential leaks through many doors:

- A step that prints an environment variable or runs with `set -x` writes the value into the log.
- A Task result is stored in the status of the TaskRun, readable by everyone who can read TaskRuns.
- A parameter value is in the spec of the run and in the script text of every step that uses it.

Pass secrets as mounted files or `valueFrom.secretKeyRef` environment variables, read them inside the step, and print sizes or names, never values. The module on parameters showed why a parameter must not carry untrusted text; the same rule says a parameter must not carry a secret.

## Common pitfalls

> [!WARNING]
> - **Forgetting the annotation.** A Secret on the service account without `tekton.dev/git-0` or `tekton.dev/docker-0` is ignored.
> - **Putting a registry login in `secrets` and expecting image pulls.** Use `imagePullSecrets`.
> - **Writing a password into a parameter or result.** Both are visible in the cluster.
> - **Using the wrong key in a workspace Secret.** The tool finds no file and falls back to anonymous access.
> - **Giving the pipeline service account more rights than it needs.** A leaked pod then does more damage.
