FROM python:3.9-slim

WORKDIR /app

# 安装基本依赖
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY . .

# 创建必要的目录
RUN mkdir -p /app/uploads /app/data

# 暴露端口
EXPOSE 5000

# 启动命令
CMD ["python", "app.py"]