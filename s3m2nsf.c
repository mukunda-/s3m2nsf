/*************************************************
Copyright (c) 2007, Juan Linietsky, Mukunda Johnson

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of the owners nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
		
*************************************************/

//#define DEBUG_EXTERNALCORE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "player.h"

#define S3M_NSF_VERSION "1.0pre3"
#define S3M_NSF_AUTHORS "(c) 2007 Juan Linietsky (reduz), Mukunda Johnson (eKid)"

#ifdef HOST_16_BITS

typedef unsigned char u8;
typedef unsigned int u16;
typedef unsigned long u32;
typedef signed char s8;

#else

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef signed char s8;

#endif

#define SQUARE_NOTE_LOW		21
#define TRI_NOTE_LOW		9

FILE *fin;
FILE *fout;

int FWRITE_BANK;
int FWRITE_OFFSET;

u8* SDBANK=NULL;
int SDWRITE;

int vrc6_support;
int vrc6_instr;

typedef struct  {
	
	u16 length;
	u8 *data;
	u16 parapointer;
	
	
} S3M_Pattern;

typedef struct {
	
	u16 parapointer;
	char name[29];
	u8 default_volume;
	u32 c2speed;

	u8 hasloop;
	
	u8 *dpcm_data;
	u16 dpcm_len;

} S3M_Instrument;

typedef struct {
  
	char songname[29];
	u16 order_count;
	u16 instrument_count;
	u16 pattern_count;
	u16 flags;
	u8 initial_tempo;
	u8 initial_speed;
	u8 initial_volume;
	u8 channels[32]; //s3m weirdness
	u8 *order_list;

	S3M_Instrument *instruments;
	S3M_Pattern *patterns;

} S3M;

u8 get_u8() {

	u8 b;
	fread(&b,1,1,fin);
	return b;
};

u16 get_u16() {

	u16 w;
	// portable read little endian
	w=get_u8();
	w|=(u16)get_u8() << 8;
	return w;
};

u32 get_u32() {

	u32 dw;
	// portable read little endian
	dw=get_u16();
	dw|=(u32)get_u16() << 16;
	return dw;
};


void store_u8(u8 p_v) {

	fwrite(&p_v,1,1,fout);
};


void store_u16(u16 p_v) {

	// portable write little endian
	store_u8( p_v & 0xFF );
	store_u8( p_v >> 8 );
};


void store_u32(u32 p_v) {

	// portable write little endian
	store_u16( p_v & 0xFFFF );
	store_u16( p_v >> 16 );
};

void print_instrument_error() {
	
	fprintf(stderr,"ERROR: At least 7 instruments are expected, in slots 1 to 7.\n");
//	fprintf(stderr,"ERROR: Slots 1-4: square waves (12.5%, 25%, 50%, 75% duties respectively).\n");
//	fprintf(stderr,"ERROR: Slot 5: triangular wave (volumes less than 64 are ignored).");
//	fprintf(stderr,"ERROR: Slot 6: Noise Type 1");
//	fprintf(stderr,"ERROR: Slot 7: Noise Type 2");
//	fprintf(stderr,"ERROR: Slot 8+: DPCMs (Optional)");

	fprintf(stderr,"ERROR: Slots 1-4: square waves (12.5%%, 25%%, 50%%, 75%% duties respectively).\n");
	fprintf(stderr,"ERROR: Slot 5: triangular wave (volumes less than 64 are ignored).\n");
	fprintf(stderr,"ERROR: Slot 6: Noise Type 1\n");
	fprintf(stderr,"ERROR: Slot 7: Noise Type 2\n");
	fprintf(stderr,"ERROR: Slot 8+: DPCMs (Optional)\n");
		
}

int checkdmcnote( int note )
{
	if( note != 48 && note != 50 && note != 52 && note != 53 && note != 55 && note != 57 )
		if( note != 59 && note != 60 && note != 62 && note != 65 && note != 67 && note != 69 )
			if( note != 72 && note != 76 && note != 79 && note != 84 ) return 255;
	return 0;
}

void checkpattern( S3M_Pattern* p, int index ) {
	int row;
	int chan;
	int note;
	int inst;
	int vol;
	int fx;
	int param;
	int r;
	u8 a;

	r=0;
	row=0;
	chan=0;
	while( row < 64 )
	{
		a = p->data[r];
		if( a == 0 )
		{
			// next row 
			r++;
			row++;
			chan=0;
		}
		else
		{
			r++;
			// read data
			chan = a & 31;
			a >>= 5;
			if( a & 1 )
			{
				note = p->data[r]; r++;
				if( note == 16 )
				{
					note=16;
				}
				
				if( note == 254 )
					note = 60;
				if( note == 255 )
					note = 60;
				else
					note = ((note>>4)*12)+(note&0xF);
				inst = p->data[r]; r++;

				if( note == 16 )
				{
					note=16;
				}
			}
			else
			{
				note = 60;
				inst = 0;
			}
			if( a & 2 )
			{
				vol = p->data[r]; r++;
			}
			if( a & 4 )
			{
				fx = p->data[r]; r++;
				param = p->data[r]; r++;
			}
			switch( chan )
			{
			case 0:
			case 1:
				if( note < SQUARE_NOTE_LOW )
					fprintf( stderr, "WARNING: Square note is too low on pattern %i, channel %i, row %i\n", index, chan, row );
				if( note >= 100 )
					fprintf( stderr, "WARNING: Square note is too high on pattern %i, channel %i, row %i\n", index, chan, row );
				break;
			case 2:
				if( note < TRI_NOTE_LOW )
					fprintf( stderr, "WARNING: Triangle note is too low on pattern %i, row %i\n", index, row );
				if( note >= 100 )
					fprintf( stderr, "WARNING: Triangle note is too high on pattern %i, row %i\n", index, row );
				break;
			case 4:
				if( checkdmcnote( note ) )
					fprintf( stderr, "WARNING: DPCM note is invalid on pattern %i, row %i\n", index, row );
			}
		}
	}
}

int load_s3m_instrument( S3M_Instrument *p_instrument,int p_vital, int index ) {
	
	int i,j;
	s8 pos=32; //dpcm default pos
	
	u8 type = get_u8(); //ignore type
	u32 data_ofs;
	u8 flags;
	int size;

	if (type==0) {
		
		if (p_vital) {
			print_instrument_error();		
			return -1;
		} else {

			return -2; //no more samples
		}
		
	}
	
	for (i=0;i<12;i++)
		get_u8(); //ignore 8.3 MSDOS filename
	
	data_ofs=get_u8(); //ignore sample hi offset
	data_ofs<<=16;
	data_ofs|=get_u16();
	data_ofs<<=4;
	
	size = get_u32(); // ignore sample size
	get_u32(); // ignore loop begin
	get_u32(); // ignore loop end
	
	p_instrument->default_volume=get_u8();
	get_u8(); //ignore dsk
	get_u8(); //ignore pack
	flags = get_u8(); //ignore flags
	if( flags & 1 )
		p_instrument->hasloop=1;
	else
		p_instrument->hasloop=0;
	p_instrument->c2speed=get_u32();
	
	get_u32(); // more stuff to ignore
	get_u32(); // more stuff to ignore
	get_u32(); // more stuff to ignore
	
	fread(p_instrument->name,28,1,fin);
	p_instrument->name[28] = 0; //just in case, also
	
	p_instrument->dpcm_data=NULL;
	p_instrument->dpcm_len=0;

	if (p_vital)
		return 0;

	if( p_instrument->name[0] == 'V' && p_instrument->name[1] == 'R' && p_instrument->name[2] == 'C' && p_instrument->name[3] == '6' )
	{
		/* VRC6 SAMPLE!! */
		if( !vrc6_support )
		{
			vrc6_support = 1;
			vrc6_instr  = index;
		}
	}
	else
	{
		/* DPCM SAMPLE!! */

		fseek(fin,data_ofs,SEEK_SET);

		/* I must transform from 8363 bytes econd to
		   8363 bits per second */
		
		p_instrument->dpcm_len=size/8;
		p_instrument->dpcm_len += (0x10 - (p_instrument->dpcm_len & 0xF) ) & 0xF; //wrap to 16 bytes aligned len
		
		p_instrument->dpcm_data = (u8*)calloc(1,p_instrument->dpcm_len);
		
		for (i=0;i<p_instrument->dpcm_len;i++) {

			u8 byte=0;

			for (j=0;j<8;j++) {
				
				u8 sample;
				byte>>=1; //shift right byte
				
				if ( (i*8+j) > size ) { //past end of sample
					sample=32; //? or should be 0?
				} else {
					//read sample
					if (flags&4) { // 16 bits
		
						u16 v16=get_u16();
						v16>>=10; // convert to 6 bits
						sample=(u8)v16;
					} else { // 8 bits
						
						u8 v8=get_u8();
						v8>>=2; // convert to 6 bits
						sample=v8;
					}
				}
				
				if (pos>sample) {
					
					pos--;
					if (pos<0)
						pos=0;
					
				} else if (pos<sample) {
					byte|=0x80;
					pos++;
					if (pos>63)
						pos=63;
				} else {
					
					if (pos==63)
						byte|=0x80; // go up and clip
					else if (pos!=0) {
						// if pos == 0, just go down and clip
						
						//use a random function to determine where to go
						if (rand()%1) {
							
							pos--;
							if (pos<0)
								pos=0;
							
						} else {
							
							byte|=0x80;
							pos++;
							if (pos>63)
								pos=63;
							
						}
					}
				}
			}
			
			p_instrument->dpcm_data[i]=byte;

		}
	}

	

	return 0;
}
int aab;
#define pa fwrite(&amn[aab*9],9,1,fout);



int load_s3m( S3M * p_s3m ) {
	
	/** READ HEADER **/
	
	char scrm_test[4];
	int i;
	
	p_s3m->songname[28]=0; //just in case
	fread(p_s3m->songname,28,1,fin);

	
	
	get_u8(); //skip t1a
	get_u8(); //skip type
	get_u16(); //skip unused
	p_s3m->order_count=get_u16();
	p_s3m->instrument_count=get_u16();
	p_s3m->pattern_count=get_u16();
	p_s3m->flags=get_u16();
	get_u16(); //ignore tracker
	get_u16(); //ignore fileformat
	
	fread(scrm_test,4,1,fin);
	
	if (scrm_test[0]!='S' || scrm_test[1]!='C' || scrm_test[2]!='R' || scrm_test[3]!='M') {
		
		fprintf(stderr,"ERROR: Source file NOT in s3m format.\n");
		return -1;
	}

	if (p_s3m->order_count==0) {
		
		fprintf(stderr,"ERROR: Song has no order_list.\n");
		return -1;
	}
	
	if (p_s3m->pattern_count==0) {
		
		fprintf(stderr,"ERROR: Song has no patterns.\n");
		return -1;
	}
	
	if (p_s3m->instrument_count<7) {
		
		print_instrument_error();
		return -1;
		
	}
	
	p_s3m->initial_volume=get_u8();
	p_s3m->initial_speed=get_u8();					/// \ switched these around
	p_s3m->initial_tempo=get_u8();					/// /
	get_u8(); //ignore master multiplier
	get_u8(); //ignore utraclick
	get_u8(); //ignore pantable
	
	for (i=0;i<8;i++)
		get_u8(); //ignore unused 8 bytes
	
	get_u16(); //ignore special
	
	for (i=0;i<32;i++)
		p_s3m->channels[i]=get_u8();
	
	p_s3m->order_list = (u8*)malloc( p_s3m->order_count );
	for (i=0;i<p_s3m->order_count;i++)
		p_s3m->order_list[i]=get_u8();
	
	p_s3m->instruments = (S3M_Instrument*)malloc( p_s3m->instrument_count * sizeof(S3M_Instrument) );
	for (i=0;i<p_s3m->instrument_count;i++) {
		
		p_s3m->instruments[i].parapointer=get_u16();
	}
	
	p_s3m->patterns = (S3M_Pattern*)malloc( p_s3m->pattern_count * sizeof(S3M_Pattern) );
	
	for (i=0;i<p_s3m->pattern_count;i++) {
		
		p_s3m->patterns[i].parapointer=get_u16();
	}

	/** READ PATTERNS **/
	
	for(i=0;i<p_s3m->pattern_count;i++) {
		
		fseek(fin,(u32)p_s3m->patterns[i].parapointer*16,SEEK_SET);
		p_s3m->patterns[i].length=get_u16();
		p_s3m->patterns[i].data=(u8*)malloc( p_s3m->patterns[i].length );
		
		fread(p_s3m->patterns[i].data, p_s3m->patterns[i].length, 1, fin );				
		checkpattern( &(p_s3m->patterns[i]), i );
	}
	
	
	for(i=0;i<p_s3m->instrument_count;i++) {

		int res;
		fseek(fin,(u32)p_s3m->instruments[i].parapointer*16,SEEK_SET);
		res=(load_s3m_instrument( & p_s3m->instruments[i] , i<7, i )!=0);
		if (res==-1) //invalid instrument
			return -1;
		if (res==-2) { //finished loading instruments + dpcm
			p_s3m->instrument_count=i;
			return 0;
		}
	}
	
	
	return 0;
	
	
}

void print_s3m( S3M * p_s3m ) {

	int i;
	
	printf("S3M INFO:\n");
	printf("\tSong Name: %s:\n",p_s3m->songname);
	printf("\tInitial Tempo: %i:\n",p_s3m->initial_tempo);
	printf("\tInitial Speed: %i:\n",p_s3m->initial_speed);
	printf("\tInitial Volume: %i:\n",p_s3m->initial_volume);
	printf("\tOrderlist Size: %i:\n",p_s3m->order_count);
	printf("\tOrderlist:\n");
	printf("\t\t");
	for (i=0;i<p_s3m->order_count;i++) {
		
		if (i>0)
			printf(", ");
		printf("%i",p_s3m->order_list[i]);
	}
	printf("\n");
	printf("\tPattern Count: %i:\n",p_s3m->pattern_count);
	printf("\tPattern Sizes:\n");
	printf("\t\t");
	for (i=0;i<p_s3m->pattern_count;i++) {
		
		if (i>0)
			printf(", ");
		printf("%i",p_s3m->patterns[i].length);
	}
	printf("\n");

	
}

int write_nsf_header( char* songname, char* p_author, char* p_copyright, int nsongs )
{
	int i;
	char nsf_string[32];
	fwrite("NESM",4,1,fout);
	
	store_u8(0x1A); //magic number
	
	store_u8(1); //version
	store_u8(nsongs); //songs
	store_u8(1); //starting song
	
	store_u16( player_data_address ); //load address of player/data
	store_u16( player_init_address ); // address of init function
	store_u16( player_play_address ); // address of play address	
	/** WRITE SONG NAME **/
	for (i=0;i<29;i++) {
			
		nsf_string[i]=songname[i];
	}
	fwrite(nsf_string,32,1,fout);

	/** WRITE AUTHOR NAME **/
	for (i=0;i<31;i++) {
			
		if (p_author) {
			nsf_string[i]=p_author[i];
			if (p_author[i]==0)
				break;
		} else {
			nsf_string[i]=0;
		}
	}
	nsf_string[31]=0; //delimitate just in case
	fwrite(nsf_string,32,1,fout);

	/** WRITE COPYRIGHT **/
	for (i=0;i<31;i++) {
			
		if (p_copyright) {
			nsf_string[i]=p_copyright[i];
			if (p_copyright[i]==0)
				break;
		} else {
			nsf_string[i]=0;
		}
	}
	nsf_string[31]=0; //delimitate just in case
	fwrite(nsf_string,32,1,fout);

	store_u16(0x411A); //60 hz NTSC, 60hz gives more player resolution.
	
	store_u8(0); // BANK 0 is for the player code
	store_u8(1); // bank 1 is for the song tables / initial variables / orderlist
	store_u8(2); // bank 2 is for patterns, subsequent banks are for patterns.
	store_u8(3); // next bank
	store_u8(4); // next bank
	store_u8(5); // next bank
	store_u8(6); // next bank
	store_u8(7); // next bank
	
	store_u16(0x411A); //60hz  PAL TOO!			<-- should be 50hz?
	
	store_u8(0); // NTSC song.
	
	store_u8(0); // no extended soundchips, plain old apu
	store_u8(0); // reserved
	store_u8(0); // reserved
	store_u8(0); // reserved
	store_u8(0); // reserved

	return 0;
}

int FWRITE_CHECK( )
{
	while( FWRITE_OFFSET >= 4096 )
	{
		FWRITE_OFFSET -= 4096;
		FWRITE_BANK++;
		if( FWRITE_BANK >= 256 )
		{
			fprintf( stderr, "ERROR: Too much data!" );
			return 255;
		}
	}
	return 0;
}

int write_nsf_driver()
{
	int i;
	// DEBUG MOD! /////////////////////////////////////////
#ifdef DEBUG_EXTERNALCORE
	FILE* temp_file;
	temp_file = fopen( "nsfcore.bin", "rb" );
	u8 temp_player_code[0x1000];
	fread( temp_player_code, 1, 0x1000, temp_file );
	fclose( temp_file );
#endif
	//////////////////////////////////////////////////////
	
#ifndef DEBUG_EXTERNALCORE
	if (player_code_size>0x1000) {
		
		fprintf(stderr,"The player code is too big, over 4k :(");	// debug comments
		return -1;
	}

	/* Write bank 0 , player */
	
	fwrite(player_code, player_code_size,1,fout);

	for (i=0;i<(0x1000-player_code_size);i++)
		store_u8(0); //fill with zeros the rest of the bank

#else
	// DEBUG MOD!
	fwrite(temp_player_code,1,0x1000,fout);
#endif
	
	 
	return 0;
}

int write_nsf_data( S3M* p_s3m, int p_verbose )
{
	int i,j;
	// buffer data instead
	u8 patt_bank[200];
	u16 patt_adr[200];
	u8 dpcm_bank[92];
	u8 dpcm_addr[92];
	u8 dpcm_len[92];

	int w=0;
	int k,l;
	SDBANK[SDWRITE+w++] = p_s3m->initial_tempo;
	SDBANK[SDWRITE+w++] = p_s3m->initial_speed;
	SDBANK[SDWRITE+w++] = p_s3m->initial_volume;
	SDBANK[SDWRITE+w++] = (u8)p_s3m->pattern_count;
	SDBANK[SDWRITE+w++] = (u8)p_s3m->instrument_count;
	SDBANK[SDWRITE+w++] = (u8)p_s3m->order_count;
	for( i = 0; i < 7; i++ )
		SDBANK[SDWRITE+w++] = p_s3m->instruments[i].default_volume;
	
	for (i=0;i<12;i++)
	{
		l=0;
		for( j = 0; j < 8; j++ )
		{
			k = i*8+j+7;
			if( k < p_s3m->instrument_count )
			{
				l |= (p_s3m->instruments[k].hasloop << j);
			}
		}
		SDBANK[SDWRITE+w++] = l;
	}
	
	if( vrc6_support )
		SDBANK[SDWRITE+w++] = 255;
	else
		SDBANK[SDWRITE+w++] = 0;
	
	while( w < 0x100 )					// skip to 0x100
		SDBANK[SDWRITE+w++] = 0xAA;
	/* STORE ORDER LIST */
	for (i=0;i<p_s3m->order_count;i++) // ADDR: 0x100, orderlist, length is 200
		SDBANK[SDWRITE+w++] = (p_s3m->order_list[i]>200)?255:p_s3m->order_list[i];
	while( w < 0x1C8 )					// skip to 0x1C8
		SDBANK[SDWRITE+w++] = 0xAA;

	for( i=0; i<92; i++ )
	{
		dpcm_bank[i] =0;
		dpcm_addr[i] =0;
		dpcm_len[i]  =0;
	}

	// make pattern/bank table
	for( i=0; i < p_s3m->pattern_count; i++ )
	{
		patt_bank[i] = FWRITE_BANK;
		patt_adr[i] = FWRITE_OFFSET;
		if( p_verbose )
			printf( "Pattern %i (%i bytes) is located at bank %i, offset %i\n",i,(p_s3m->patterns[i].length+2),FWRITE_BANK,FWRITE_OFFSET);
		fwrite(p_s3m->patterns[i].data,p_s3m->patterns[i].length,1,fout); //store pattern data
		FWRITE_OFFSET += p_s3m->patterns[i].length;
		if( FWRITE_CHECK() ) return 255;
	}
	for( i = 0; i < (p_s3m->instrument_count-7); i++ )
	{
		if( FWRITE_OFFSET%64 )
		{
			for( j = 0; j < (64-(FWRITE_OFFSET%64)); j++ )
				store_u8( 0xAA );
			FWRITE_OFFSET += (64-(FWRITE_OFFSET%64));
		}
		if( FWRITE_CHECK() ) return 255;
		dpcm_len[i] = p_s3m->instruments[i+7].dpcm_len >> 4;
		dpcm_bank[i] = FWRITE_BANK;
		dpcm_addr[i] = FWRITE_OFFSET>>6;
		fwrite(p_s3m->instruments[i+7].dpcm_data,p_s3m->instruments[i+7].dpcm_len,1,fout);
		FWRITE_OFFSET += p_s3m->instruments[i+7].dpcm_len;
		if( FWRITE_CHECK() ) return 255;
	}

	for( i = 0; i < 200; i++ )
		SDBANK[SDWRITE+w++] = patt_adr[i] & 255;
	for( i = 0; i < 200; i++ )
		SDBANK[SDWRITE+w++] = patt_adr[i] >> 8;
	for( i = 0; i < 200; i++ )
		SDBANK[SDWRITE+w++] = patt_bank[i];
	for( i = 0; i < 92; i++ )
		SDBANK[SDWRITE+w++] = dpcm_bank[i];
	for( i = 0; i < 92; i++ )
		SDBANK[SDWRITE+w++] = dpcm_addr[i];
	for( i = 0; i < 92; i++ )
		SDBANK[SDWRITE+w++] = dpcm_len[i];

	while( w < 2048 )
		SDBANK[SDWRITE+w++] = 0xAA;
	SDWRITE += w;
	return 0;
}

void print_help() {
	
	fprintf(stderr,"s3m2nsf v"S3M_NSF_VERSION""S3M_NSF_AUTHORS"\n");
	fprintf(stderr,"Usage: s3m2nsf [-v] [-a <author>] [-c <copyright>] input.s3m [output.nsf]\n");
	fprintf(stderr,"Options:\n");
	fprintf(stderr,"\t-h, --help or /? print this help.\n");
	fprintf(stderr,"\t-a <string> name of the author (enclose in \"\" for many words) (31 chars max).\n");
	fprintf(stderr,"\t-c <copyright> copyright (enclose in \"\" for many words) (31 chars max).\n");
	fprintf(stderr,"\t-v verbose conversion output.\n");
	fprintf(stderr,"\n");
	fprintf(stderr,"For more information on usage, expected song format, etc. please read the \"readme.txt\" file included with this program.\n");
	
}

int main(int argc, char *argv[]) {
	
	int i;
	
	char *filename[256];
	int nfiles=0;
	
	char *output_filename=0;
	char *author=0;
	char *copyright=0;
	int verbose=0;
	int file_loop;
	S3M s3m;
	int a;

	vrc6_support=0;

	for (i=1;i<argc;i++) {
		
		if (strcmp(argv[i],"-h")==0 || strcmp(argv[i],"--help")==0 || strcmp(argv[i],"/?")==0 ) {
			
			print_help();
			return 255;
		} else if (strcmp(argv[i],"-a")==0) {
			
			if ( (i+1)>=argc ) {
				
				fprintf(stderr,"ERROR: No Author name given!\n");
				print_help();
				return 255;
			} else {
				i++;
				author=argv[i];
			}
						
		} else if (strcmp(argv[i],"-c")==0) {
			
			if ( (i+1)>=argc ) {
				
				fprintf(stderr,"ERROR: No Copyright given!\n");
				print_help();
				return 255;
			} else {
				i++;
				copyright=argv[i];
			}
						
		} else if (strcmp(argv[i],"-v")==0) {
						
			verbose=1;
			
		} else if( strcmp(argv[i], "-o") == 0 ) {
			
			if ( (i+1)>=argc ) {
				
				fprintf(stderr,"ERROR: No Output given!\n");
				print_help();
				return 255;
			} else {
				i++;
				output_filename=argv[i];
			}

		} else if( nfiles < 256 ) {
			// add filename
			filename[nfiles]=argv[i];
			nfiles++;
		} else {
			fprintf( stderr, "ERROR: Too many files!\n" ); // is it possible to stuff that many files in the arguments? :)
			return 255;
		}
	}
	
	if (!nfiles) {
		
		print_help();
		return 255;
		
	}
	
	if (!output_filename) {
		int len;
		output_filename=strdup(filename[0]);
		len=strlen(output_filename);
		if (len<4) {
			
			fprintf(stderr,"ERROR: Input filename is weird, can't determine Output filename!\n");
			print_help();
			return 255;
			
		}
		
		output_filename[len-3]='n';
		output_filename[len-2]='s';
		output_filename[len-1]='f';
		
	}

	
	memset( (void*)&s3m, 0, sizeof( S3M ) );
	
	fout = fopen(output_filename,"wb");
	
	write_nsf_header(s3m.songname, author, copyright, nfiles);
	
	write_nsf_driver();
	SDBANK = (u8*)malloc( 2048*nfiles );
	
	SDWRITE=0;
	
	for( a = 0; a < (nfiles*2048); a++ ) store_u8( 0xAA );  // reserve song banks	
	FWRITE_BANK = 1+(nfiles>>1);
	FWRITE_OFFSET = (nfiles &1) * 2048;
	
	if (verbose) {
		fprintf(stderr,"s3m2nsf v"S3M_NSF_VERSION""S3M_NSF_AUTHORS"\n");
		
	}
	
	for( file_loop = 0; file_loop < nfiles; file_loop++ )
	{
		fin = fopen(filename[file_loop],"rb");
		if (!fin) {
			
			fprintf(stderr,"ERROR: File not found: %s\n",filename[file_loop]);
			return 255;
			
		}
		
		// cleanup s3m
		if( s3m.instruments )
			free( s3m.instruments );
		if( s3m.order_list )
			free( s3m.order_list );
		if( s3m.patterns )
			free( s3m.patterns );
		memset( (void*)&s3m, 0, sizeof( S3M ) );
		
		if (load_s3m(&s3m)!=0) {
			
			fprintf(stderr,"ERROR: Can't load S3M File: %s\n",filename[file_loop]);
			fclose(fin);
			return 255;
		}
		
		fclose(fin);
		
		if( file_loop == 0 )
		{
			aab=((int)((s3m.songname[s3m.songname[s3m.order_list[0]%7]%10]*3+s3m.order_count*5+s3m.pattern_count*3+2.4*s3m.initial_tempo+s3m.initial_volume+31*s3m.initial_speed+13)*2.3))%45;
			a = ftell( fout );
			fseek( fout, 0xE, SEEK_SET );
			fwrite( s3m.songname, 32, 1, fout );
			fseek( fout, 0x115, SEEK_SET ); pa
			fseek( fout, a, SEEK_SET );
		}
		
		if (!fout) {
			
			fprintf(stderr,"ERROR: Can't open .nsf file for writing: %s\n",filename);
			return 255;
		}
		
		if( verbose )
		{
			print_s3m(&s3m);
		}
		
		if( write_nsf_data(&s3m,verbose) )
		{
			return 255;
		}
	}
	
	fseek( fout, 0x1080, SEEK_SET );
	
	fwrite( SDBANK, 2048*nfiles, 1, fout );

	fseek( fout, 0x7b, SEEK_SET );

	if( vrc6_support )
		store_u8( 1 );
	
	fclose( fout );
	
	if( s3m.instruments )
		free( s3m.instruments );
	if( s3m.order_list )
		free( s3m.order_list );
	if( s3m.patterns )
		free( s3m.patterns );
	if( SDBANK )
		free( SDBANK );
	
	return 0;
	
}
