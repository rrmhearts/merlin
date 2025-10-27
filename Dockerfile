# Use the latest Ubuntu image
FROM ubuntu:latest

# Install system dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
    git \
    gcc \
    g++ \
    make \
    zip unzip gawk \
    autotools-dev \
    cmake \
    csh \
    libtool \
    build-essential \
    pkg-config \
    libncurses5-dev \
    libncursesw5-dev \
    libx11-dev \
    libsndfile1-dev \
    libssl-dev \
    libcurses-ocaml \
    libxml2-dev \
    libxslt-dev \
    software-properties-common \
    wget curl \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Add the 'deadsnakes' PPA for newer Python versions
RUN add-apt-repository ppa:deadsnakes/ppa -y

# Update package lists again after adding the PPA
RUN apt-get update

# Install Python 3.10 and its development headers
RUN apt-get install -y python3.10 python3.10-dev python3.10-venv python-is-python3

# Install pip for Python 3.10
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10

# Set Python 3.10 as the default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

# Verify the Python version
RUN python3 --version

RUN python -m pip install --upgrade pip

# Set the working directory
WORKDIR /app

# Copy the application code
COPY . .

# Make the install scripts executable
RUN chmod +x ./install*.sh ./tools/*.sh

# Run install.sh
RUN ./install.sh

#Install requirments.txt if exits
RUN if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

# Test by running demo.  This will likely need adjustment based on your environment.
CMD cd egs/build_your_own_voice/s1_python && python run_merlin_workflow.py --setup-data --train-tts --run-tts