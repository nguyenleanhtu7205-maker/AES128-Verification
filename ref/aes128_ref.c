#include <string.h>

#ifndef AES_STANDALONE
#include "svdpi.h"
#endif

/* ---- tables -------------------------------------------------------- */
static const unsigned char SBOX[256] = {
  0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
  0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
  0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
  0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
  0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
  0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
  0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
  0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
  0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
  0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
  0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
  0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
  0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
  0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
  0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
  0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
};

static unsigned char INV[256];
static int inv_ready = 0;

static void build_inv(void)
{
  int i;
  for (i = 0; i < 256; i++) INV[SBOX[i]] = (unsigned char)i;
  inv_ready = 1;
}

static const unsigned char RCON[11] = {
  0x00,0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36
};

/* ---- GF(2^8) ------------------------------------------------------- */
static unsigned char xt(unsigned char b)
{
  return (unsigned char)((b << 1) ^ ((b & 0x80) ? 0x1b : 0x00));
}

static unsigned char gmul(unsigned char a, unsigned char b)
{
  unsigned char r = 0;
  while (b) {
    if (b & 1) r ^= a;
    a = xt(a);
    b >>= 1;
  }
  return r;
}

/* ---- key schedule: rk[r][16], r = 0..10 ---------------------------- */
static void key_expand(const unsigned char *key, unsigned char rk[11][16])
{
  unsigned char w[44][4];
  int i, j;

  for (i = 0; i < 4; i++)
    for (j = 0; j < 4; j++) w[i][j] = key[4 * i + j];

  for (i = 4; i < 44; i++) {
    unsigned char t[4];
    if (i % 4 == 0) {
      t[0] = (unsigned char)(SBOX[w[i - 1][1]] ^ RCON[i / 4]);
      t[1] = SBOX[w[i - 1][2]];
      t[2] = SBOX[w[i - 1][3]];
      t[3] = SBOX[w[i - 1][0]];
    } else {
      for (j = 0; j < 4; j++) t[j] = w[i - 1][j];
    }
    for (j = 0; j < 4; j++) w[i][j] = (unsigned char)(w[i - 4][j] ^ t[j]);
  }

  for (i = 0; i < 11; i++)
    for (j = 0; j < 16; j++) rk[i][j] = w[4 * i + j / 4][j % 4];
}

/* ---- round steps --------------------------------------------------- */
static void add_rk(unsigned char *s, const unsigned char *k)
{
  int i;
  for (i = 0; i < 16; i++) s[i] = (unsigned char)(s[i] ^ k[i]);
}

static void sub_bytes(unsigned char *s, const unsigned char *box)
{
  int i;
  for (i = 0; i < 16; i++) s[i] = box[s[i]];
}

static void shift_rows(unsigned char *s, int inv)
{
  unsigned char o[16];
  int r, c, src;
  for (r = 0; r < 4; r++)
    for (c = 0; c < 4; c++) {
      src = inv ? ((c - r) & 3) : ((c + r) & 3);
      o[4 * c + r] = s[4 * src + r];
    }
  memcpy(s, o, 16);
}

static void mix_cols(unsigned char *s, int inv)
{
  static const unsigned char MF[4][4] = {
    {2,3,1,1}, {1,2,3,1}, {1,1,2,3}, {3,1,1,2}
  };
  static const unsigned char MI[4][4] = {
    {14,11,13,9}, {9,14,11,13}, {13,9,14,11}, {11,13,9,14}
  };
  unsigned char o[16];
  int c, r, j;
  for (c = 0; c < 4; c++)
    for (r = 0; r < 4; r++) {
      unsigned char v = 0;
      for (j = 0; j < 4; j++)
        v ^= gmul(s[4 * c + j], inv ? MI[r][j] : MF[r][j]);
      o[4 * c + r] = v;
    }
  memcpy(s, o, 16);
}

/* ---- the two ciphers ----------------------------------------------- */
void aes128_enc_bytes(const unsigned char *key, const unsigned char *pt,
                      unsigned char *ct)
{
  unsigned char rk[11][16], s[16];
  int r;
  key_expand(key, rk);
  memcpy(s, pt, 16);
  add_rk(s, rk[0]);
  for (r = 1; r <= 9; r++) {
    sub_bytes(s, SBOX);
    shift_rows(s, 0);
    mix_cols(s, 0);
    add_rk(s, rk[r]);
  }
  sub_bytes(s, SBOX);
  shift_rows(s, 0);
  add_rk(s, rk[10]);
  memcpy(ct, s, 16);
}

void aes128_dec_bytes(const unsigned char *key, const unsigned char *ct,
                      unsigned char *pt)
{
  unsigned char rk[11][16], s[16];
  int r;
  if (!inv_ready) build_inv();
  key_expand(key, rk);
  memcpy(s, ct, 16);
  add_rk(s, rk[10]);
  for (r = 9; r >= 1; r--) {
    shift_rows(s, 1);
    sub_bytes(s, INV);
    add_rk(s, rk[r]);
    mix_cols(s, 1);
  }
  shift_rows(s, 1);
  sub_bytes(s, INV);
  add_rk(s, rk[0]);
  memcpy(pt, s, 16);
}

/* ---- DPI glue ------------------------------------------------------ */
#ifndef AES_STANDALONE

/* FIPS byte i sits at bits [127-8i : 120-8i] of the SV vector.
 * svBitVecVal word w holds bits [32w+31 : 32w]. */
static void unpack(const svBitVecVal *v, unsigned char *b)
{
  int i, lo;
  for (i = 0; i < 16; i++) {
    lo = 120 - 8 * i;
    b[i] = (unsigned char)((v[lo >> 5] >> (lo & 31)) & 0xffu);
  }
}

static void pack(const unsigned char *b, svBitVecVal *v)
{
  int i, lo;
  for (i = 0; i < 4; i++) v[i] = 0;
  for (i = 0; i < 16; i++) {
    lo = 120 - 8 * i;
    v[lo >> 5] |= ((svBitVecVal)b[i]) << (lo & 31);
  }
}

void aes128_enc_ref(const svBitVecVal *key, const svBitVecVal *pt,
                    svBitVecVal *ct)
{
  unsigned char kb[16], ib[16], ob[16];
  unpack(key, kb);
  unpack(pt, ib);
  aes128_enc_bytes(kb, ib, ob);
  pack(ob, ct);
}

void aes128_dec_ref(const svBitVecVal *key, const svBitVecVal *ct,
                    svBitVecVal *pt)
{
  unsigned char kb[16], ib[16], ob[16];
  unpack(key, kb);
  unpack(ct, ib);
  aes128_dec_bytes(kb, ib, ob);
  pack(ob, pt);
}

#else /* ---- standalone self-test ---- */

#include <stdio.h>

static int hex16(const char *h, unsigned char *b)
{
  int i;
  unsigned u;
  for (i = 0; i < 16; i++) {
    if (sscanf(h + 2 * i, "%2x", &u) != 1) return 0;
    b[i] = (unsigned char)u;
  }
  return 1;
}

static void show(const char *tag, const unsigned char *b)
{
  int i;
  printf("%s", tag);
  for (i = 0; i < 16; i++) printf("%02x", b[i]);
  printf("\n");
}

int main(void)
{
  static const char *V[3][3] = {
    {"000102030405060708090a0b0c0d0e0f",
     "00112233445566778899aabbccddeeff",
     "69c4e0d86a7b0430d8cdb78070b4c55a"},
    {"2b7e151628aed2a6abf7158809cf4f3c",
     "3243f6a8885a308d313198a2e0370734",
     "3925841d02dc09fbdc118597196a0b32"},
    {"00000000000000000000000000000000",
     "00000000000000000000000000000000",
     "66e94bd4ef8a2c3b884cfa59ca342b2e"}
  };
  unsigned char k[16], p[16], c[16], got[16], back[16];
  int i, fail = 0;

  for (i = 0; i < 3; i++) {
    hex16(V[i][0], k); hex16(V[i][1], p); hex16(V[i][2], c);
    aes128_enc_bytes(k, p, got);
    if (memcmp(got, c, 16)) { printf("enc vector %d FAIL\n", i); show("  got ", got); fail++; }
    else printf("enc vector %d ok\n", i);
    aes128_dec_bytes(k, c, back);
    if (memcmp(back, p, 16)) { printf("dec vector %d FAIL\n", i); show("  got ", back); fail++; }
    else printf("dec vector %d ok\n", i);
  }

  /* round trip on a sweep of patterns */
  for (i = 0; i < 2000; i++) {
    int j;
    for (j = 0; j < 16; j++) {
      k[j] = (unsigned char)(i * 7 + j * 31 + 5);
      p[j] = (unsigned char)(i * 13 + j * 17 + 101);
    }
    aes128_enc_bytes(k, p, c);
    aes128_dec_bytes(k, c, back);
    if (memcmp(back, p, 16)) { printf("round trip %d FAIL\n", i); fail++; break; }
  }
  if (!fail) printf("round trip: 2000/2000 ok\n");

  printf(fail ? "REF FAILED\n" : "REF PASSED\n");
  return fail ? 1 : 0;
}

#endif