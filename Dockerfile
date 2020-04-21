#----------------------------------- #
# gdal-base image with full build deps
# github: perrygeo/docker-gdal-base
# docker: perrygeo/gdal-base
#----------------------------------- #
FROM python:3.8-slim-buster as builder

RUN apt-get update
RUN apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        g++ \
        gcc \
        gfortran \
        git \
        libfreexl-dev \
        libgrib-api-dev \
        libxml2-dev \
        pkg-config \
        python3-dev \
        unzip \
        zlib1g-dev \
        wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# using gdal master
ENV CURL_VERSION 7.61.1
ENV GDAL_VERSION 3.0.4
ENV GEOS_VERSION 3.8.0
ENV OPENJPEG_VERSION 2.3.1
ENV PROJ_VERSION 7.0.0
ENV SPATIALITE_VERSION 4.3.0a
ENV SQLITE_VERSION 3270200
ENV WEBP_VERSION 1.0.0
ENV ZSTD_VERSION 1.3.4
ENV TIFF_VERSION 4.1.0
ENV GEOTIFF_VERSION 1.5.1
ENV ECCODES_VERSION=2.16.0
ENV NUMPY_VERSION=1.18.2
ENV PANDAS_VERSION=1.0.3

RUN wget -q https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VERSION}.tar.gz
RUN wget -q -O zstd-${ZSTD_VERSION}.tar.gz https://github.com/facebook/zstd/archive/v${ZSTD_VERSION}.tar.gz
RUN wget -q https://download.osgeo.org/geos/geos-${GEOS_VERSION}.tar.bz2
RUN wget -q https://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz
RUN wget -q https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz
RUN wget -q http://download.osgeo.org/geotiff/libgeotiff/libgeotiff-${GEOTIFF_VERSION}.tar.gz
RUN wget -q -O openjpeg-${OPENJPEG_VERSION}.tar.gz https://github.com/uclouvain/openjpeg/archive/v${OPENJPEG_VERSION}.tar.gz
RUN wget -q https://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz
RUN wget -q https://www.sqlite.org/2019/sqlite-autoconf-${SQLITE_VERSION}.tar.gz
RUN wget -q https://www.gaia-gis.it/gaia-sins/libspatialite-${SPATIALITE_VERSION}.tar.gz
RUN wget -q https://download.osgeo.org/proj/proj-datumgrid-1.8.zip
RUN wget -q https://confluence.ecmwf.int/download/attachments/45757960/eccodes-${ECCODES_VERSION}-Source.tar.gz

RUN tar xzf libwebp-${WEBP_VERSION}.tar.gz && \
    cd libwebp-${WEBP_VERSION} && \
    CFLAGS="-O2 -Wl,-S" ./configure --enable-silent-rules && \
    echo "building WEBP ${WEBP_VERSION}..." \
    make --quiet -j"$(nproc)" && make --quiet install

RUN tar -zxf zstd-${ZSTD_VERSION}.tar.gz \
    && cd zstd-${ZSTD_VERSION} \
    && echo "building ZSTD ${ZSTD_VERSION}..." \
    && make --quiet -j"$(nproc)" ZSTD_LEGACY_SUPPORT=0 CFLAGS=-O1 \
    && make --quiet install ZSTD_LEGACY_SUPPORT=0 CFLAGS=-O1

RUN tar -xjf geos-${GEOS_VERSION}.tar.bz2 \
    && cd geos-${GEOS_VERSION} \
    && ./configure --prefix=/usr/local \
    && echo "building geos ${GEOS_VERSION}..." \
    && make --quiet -j"$(nproc)" && make --quiet install

RUN tar -xzvf sqlite-autoconf-${SQLITE_VERSION}.tar.gz && cd sqlite-autoconf-${SQLITE_VERSION} \
    && ./configure --prefix=/usr/local \
    && echo "building SQLITE ${SQLITE_VERSION}..." \
    && make --quiet -j"$(nproc)" && make --quiet install

RUN wget -q https://download.osgeo.org/libtiff/tiff-${TIFF_VERSION}.tar.gz \
    && tar -xf tiff-${TIFF_VERSION}.tar.gz \
    && cd tiff-${TIFF_VERSION} \
    && ./configure \
    && make -j "$(nproc)" && make install


RUN tar -xzf curl-${CURL_VERSION}.tar.gz && cd curl-${CURL_VERSION} \
    && ./configure --prefix=/usr/local \
    && echo "building CURL ${CURL_VERSION}..." \
    && make --quiet -j"$(nproc)" && make --quiet install


RUN tar -xzf proj-${PROJ_VERSION}.tar.gz \
    && unzip proj-datumgrid-1.8.zip -d proj-${PROJ_VERSION}/data \
    && cd proj-${PROJ_VERSION} \
    && ./configure --prefix=/usr/local \
    && echo "building proj ${PROJ_VERSION}..." \
    && make --quiet -j"$(nproc)" && make --quiet install

# Doesn't appear to be updated for proj6, not worth holding up the show
# RUN tar -xzvf libspatialite-${SPATIALITE_VERSION}.tar.gz && cd libspatialite-${SPATIALITE_VERSION} \
#     && ./configure --prefix=/usr/local \
#     && echo "building SPATIALITE ${SPATIALITE_VERSION}..." \
#     && make --quiet -j"$(nproc)" && make --quiet install

RUN tar -xf libgeotiff-${GEOTIFF_VERSION}.tar.gz \
    && cd libgeotiff-${GEOTIFF_VERSION} \
    && ./configure \
    && make -j "$(nproc)" && make install

RUN tar -zxf openjpeg-${OPENJPEG_VERSION}.tar.gz \
    && cd openjpeg-${OPENJPEG_VERSION} \
    && mkdir build && cd build \
    && cmake .. -DBUILD_THIRDPARTY:BOOL=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
    && echo "building openjpeg ${OPENJPEG_VERSION}..." \
    && make --quiet -j"$(nproc)" && make --quiet install

RUN tar -xzf gdal-${GDAL_VERSION}.tar.gz && cd gdal-${GDAL_VERSION} && \
    ./configure \
        --disable-debug \
        --disable-static \
        --prefix=/usr/local \
        --with-curl=/usr/local/bin/curl-config \
        --with-geos \
        --with-geotiff=internal \
        --with-hide-internal-symbols=yes \
        --with-libtiff=internal \
        --with-openjpeg \
        --with-sqlite3 \
        --with-spatialite \
        --with-proj=/usr/local \
        --with-rename-internal-libgeotiff-symbols=yes \
        --with-rename-internal-libtiff-symbols=yes \
        --with-threads=yes \
        --with-webp=/usr/local \
        --with-zstd=/usr/local \
        --with-python \
    && echo "building GDAL ${GDAL_VERSION}..." \
    && make --quiet -j"$(nproc)" && make --quiet install


# Install NumPy & Pandas
RUN CFLAGS="-g0" pip install \
        numpy==${NUMPY_VERSION} \
        pandas==${PANDAS_VERSION} \
            --no-cache-dir \
            --compile \
            --global-option=build_ext

RUN tar -xzf  eccodes-$ECCODES_VERSION-Source.tar.gz && \
    mkdir build && \
    cd build && \
    cmake \
        -ENABLE_NETCDF=OFF \
        -ENABLE_JPG=OFF \
        -ENABLE_PNG=OFF \
        -ENABLE_PYTHON=OFF \
        -ENABLE_FORTRAN=OFF \
        ../eccodes-$ECCODES_VERSION-Source \
    && make -j"$(nproc)" && make install

RUN git clone https://github.com/jswhit/pygrib.git && \
    cd pygrib && \
    git checkout dbe46fb2b2a833c59dfc91cf49e4703ffa45447d && \
    pip install pyproj
COPY ./setup.cfg ./pygrib/setup.cfg

RUN cd pygrib && \
    python setup.py build && \
    python setup.py install && \
    python test.py

RUN ldconfig

# Remove archived libs in order to shrink image size
RUN rm -f /usr/local/lib/*.a

FROM python:3.8-slim as final

COPY --from=builder /usr/local/ /usr/local/
