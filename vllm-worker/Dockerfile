FROM vllm/vllm-openai:v0.27.1

USER root

# Install tools needed for AWS CLI installation.
RUN apt-get update && \
    apt-get install -y curl unzip && \
    rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2.
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "/tmp/awscliv2.zip" && \
    cd /tmp && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

COPY start.sh /app/start.sh

RUN chmod +x /app/start.sh

ENTRYPOINT ["/app/start.sh"]
