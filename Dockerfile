FROM vincejah/python-scientific:0.1

ARG GDAL_VERSION=3.0.4
ARG GDAL_SOURCE_DIR=/usr/local/src/python-gdal

ARG PROJ_VERSION=6.3.1
ARG PROJ_SOURCE_DIR=/usr/local/src/proj

# Install runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        wget \
        automake libtool pkg-config libsqlite3-dev sqlite3 \
        libpq-dev \
        libcurl4-gnutls-dev \
        libproj-dev \
        libxml2-dev \
        libgeos-dev \
        libnetcdf-dev \
        libpoppler-dev \
        libspatialite-dev \
        libhdf4-alt-dev \
        libhdf5-serial-dev \
        libopenjp2-7-dev \
    && rm -rf /var/lib/apt/lists/*

# Build against PROJ master (which will be released as PROJ 6.0)
RUN mkdir -p "${PROJ_SOURCE_DIR}" \
    && cd "${PROJ_SOURCE_DIR}" \
    && wget "http://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz" \
    && tar -xzf "proj-${PROJ_VERSION}.tar.gz" \
    && mv proj-${PROJ_VERSION} proj \
    && echo "#!/bin/sh" > proj/autogen.sh \
    && chmod +x proj/autogen.sh \
    && cd proj \
    && ./autogen.sh \
    && CXXFLAGS='-DPROJ_RENAME_SYMBOLS' CFLAGS='-DPROJ_RENAME_SYMBOLS' ./configure --disable-static --prefix=/usr/local \
    && make -j"$(nproc)" \
    && make -j"$(nproc)" install

# Rename the library to libinternalproj
RUN mv /usr/local/lib/libproj.so.15.3.1 /usr/local/lib/libinternalproj.so.15.3.1 \
    && rm /usr/local/lib/libproj.so* \
    && rm /usr/local/lib/libproj.la \
    && ln -s libinternalproj.so.15.3.1 /usr/local/lib/libinternalproj.so.15 \
    && ln -s libinternalproj.so.15.3.1 /usr/local/lib/libinternalproj.so

# Clean up PROJ sources
RUN rm -rf "${PROJ_SOURCE_DIR}"

##################
# GDAL
##################
RUN mkdir -p "${GDAL_SOURCE_DIR}" \
    && cd "${GDAL_SOURCE_DIR}" \
    # Get latest GDAL source
    && wget "http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz" \
    && tar -xvf "gdal-${GDAL_VERSION}.tar.gz" \
    # Compile and install GDAL
    && cd "gdal-${GDAL_VERSION}" \
    && export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH \
    && ./configure \
            --with-python \
            --with-curl \
            --with-openjpeg \
            --without-libtool \
            --with-proj=/usr/local \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig

# Cleanup GDAL sources
RUN rm -rf "${GDAL_SOURCE_DIR}"

# Clean up
RUN apt-get update -y \
    && apt-get remove -y --purge build-essential wget \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
