typedef struct {
  union {
    struct {
      uint32_t h;
    };
    uint8_t b[4];
  };
} lua_zip_header;

typedef struct __attribute__((packed)) {
  uint32_t header;                // offset 0
  uint16_t minVersion;            // offset 4
  uint16_t generalFlag;           // offset 6
  uint16_t compressionMethod;     // offset 8
  uint16_t lastModifiedTime;      // offset 10
  uint16_t lastModifiedData;      // offset 12
  uint32_t crc32;                 // offset 14
  uint32_t compressedSize;        // offset 18
  uint32_t uncompressedSize;      // offset 26
  uint16_t fileNameLength;        // offset 28
  uint16_t extraFieldLength;      // offset 30
  // uint8_t fileName[fileNameLength];
  // uint8_t extraField[extraFieldLength];
} lua_zip_file_entry;

typedef struct __attribute__((packed)) {
  uint32_t header;                // offset 0
  uint16_t version;
  uint16_t minVersion;            // offset 4
  uint16_t generalFlag;           // offset 6
  uint16_t compressionMethod;     // offset 8
  uint16_t lastModifiedTime;      // offset 10
  uint16_t lastModifiedData;      // offset 12
  uint32_t crc32;                 // offset 14
  uint32_t compressedSize;        // offset 18
  uint32_t uncompressedSize;      // offset 26
  uint16_t fileNameLength;        // offset 28
  uint16_t extraFieldLength;      // offset 30
  uint16_t fileCommentLength;
  uint16_t diskNumberFileStarts;
  uint16_t internalFileAttributes;
  uint32_t externalFileAttributes;
  uint32_t fileHeaderOffset;
  // uint8_t fileName[fileNameLength];
  // uint8_t extraField[extraFieldLength];
  // uint8_t fileComment[fileCommentLength];
} lua_zip_central_directory; // End Of Central Directory record

typedef struct __attribute__((packed)) {
  uint32_t header;                  // offset 0
  uint16_t numberOfDisk;            // offset 4
  uint16_t diskWhereCentralDir;     // offset 6
  uint16_t numberCentralDirsOnDisk; // offset 8
  uint16_t totalCentralDirs;        // offset 10
  uint32_t sizeOfCentralDir;        // offset 12
  uint32_t offsetOfCentralDir;      // offset 16
  uint16_t commentLength;           // offset 20
  // uint8_t comment[commentLength];
} lua_zip_eocd; // End Of Central Directory record

// zlib
enum {
    Z_NO_FLUSH           = 0,
    Z_PARTIAL_FLUSH      = 1,
    Z_SYNC_FLUSH         = 2,
    Z_FULL_FLUSH         = 3,
    Z_FINISH             = 4,
    Z_BLOCK              = 5,
    Z_TREES              = 6,
    /* Allowed flush values; see deflate() and inflate() below for details */
    Z_OK                 = 0,
    Z_STREAM_END         = 1,
    Z_NEED_DICT          = 2,
    Z_ERRNO              = -1,
    Z_STREAM_ERROR       = -2,
    Z_DATA_ERROR         = -3,
    Z_MEM_ERROR          = -4,
    Z_BUF_ERROR          = -5,
    Z_VERSION_ERROR      = -6,
    /* Return codes for the compression/decompression functions. Negative values
    * are errors, positive values are used for special but normal events.
    */
    Z_NO_COMPRESSION      =  0,
    Z_BEST_SPEED          =  1,
    Z_BEST_COMPRESSION    =  9,
    Z_DEFAULT_COMPRESSION = -1,
    /* compression levels */
    Z_FILTERED            =  1,
    Z_HUFFMAN_ONLY        =  2,
    Z_RLE                 =  3,
    Z_FIXED               =  4,
    Z_DEFAULT_STRATEGY    =  0,
    /* compression strategy; see deflateInit2() below for details */
    Z_BINARY              =  0,
    Z_TEXT                =  1,
    Z_ASCII               =  Z_TEXT,   /* for compatibility with 1.2.2 and earlier */
    Z_UNKNOWN             =  2,
    /* Possible values of the data_type field (though see inflate()) */
    Z_DEFLATED            =  8,
    /* The deflate compression method (the only one supported in this version) */
    Z_NULL                =  0,  /* for initializing zalloc, zfree, opaque */
};
typedef void*    (* z_alloc_func)( void* opaque, unsigned items, unsigned size );
typedef void     (* z_free_func) ( void* opaque, void* address );
typedef struct z_stream_s {
   char*         next_in;
   unsigned      avail_in;
   unsigned long total_in;
   char*         next_out;
   unsigned      avail_out;
   unsigned long total_out;
   char*         msg;
   void*         state;
   z_alloc_func  zalloc;
   z_free_func   zfree;
   void*         opaque;
   int           data_type;
   unsigned long adler;
   unsigned long reserved;
} z_stream;
const char*   zlibVersion();
const char*   zError(int);
int inflate(z_stream*, int flush);
int inflateEnd(z_stream*);
int inflateInit2_(z_stream*, int windowBits, const char* version, int stream_size);
int deflate(z_stream*, int flush);
int deflateEnd(z_stream* );
int deflateInit2_(z_stream*, int level, int method, int windowBits, int memLevel,int strategy, const char *version, int stream_size);
unsigned long adler32(unsigned long adler, const char *buf, unsigned len);
unsigned long crc32(unsigned long crc,   const char *buf, unsigned len);
unsigned long adler32_combine(unsigned long, unsigned long, long);
unsigned long crc32_combine(unsigned long, unsigned long, long);
