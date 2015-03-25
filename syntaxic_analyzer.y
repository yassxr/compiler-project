%{
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
	#include <string.h>
#include "tab_symboles.h"
#include "tab_ic.h"

#define NB_VAR_TEMPORAIRE_MAX 50
// Nb maximum de characteres dans une ligne de code assembleur que le compilateur peut générer
#define LINE_CAPACITY 100
#define WORD_CAPACITY 32

int ligneAsmCourant = 1;
int flagConst ;
int nbVarTmpCourant = 0;
char nomVarTmpCourant[NB_VAR_TEMPORAIRE_MAX];
const char* MARQUEUR_TIC = "???";
FILE* fp ;

%}

%token  EXP TXT 
%token  tEGAL tPLUS tMOINS tFOIS  tDIVISE
%token  tPARO tPARF tACCO tACCF
%token  tINT tCONST  
%token  tSPACE tVIRGULE tFININSTRUCTION tDEUXPOINTS
%token  tECHO tMAIN tIF tELSE
%error-verbose

%token <chaine> VAR
%union {char* chaine;} 

%token <nombre> NOMBRE
%union {int nombre;}

%type <expr> Expression
%union {int expr;}


%left tPLUS  tMOINS
%left tFOIS  tDIVISE
%right tEGAL

%start Input
%%

Input:			Debut ; 

Debut:			tMAIN tPARO tPARF tACCO Operations Fin ; 

Operations:		Declarations Instructions ;   

Declarations:		Declaration Declarations
			| 
			; 

Declaration: tINT  {flagConst = 0;} VariablesDeclarations                 
			| tCONST tINT {flagConst = 1;} VariablesDeclarations	
			;

VariablesDeclarations:  VAR tFININSTRUCTION {if (ts_addr($1) == -1) { 
		  										ts_ajouter($1, flagConst, 0);
		  									  } else { 
		  									  	printf("ERREUR : Symbole déjà déclarée\n"); 
		  									  }}
					  | VAR tEGAL NOMBRE tFININSTRUCTION {if (ts_addr($1) == -1) { 
					  										ts_ajouter($1, flagConst, 1);  
					  										fprintf(fp, "AFC %d %d\n", ts_addr($1), $3);
					  										ligneAsmCourant++;
					  									  } else { 
					  									  	printf("ERREUR : Symbole déjà déclarée\n"); 
					  									  }}
					  | VAR tVIRGULE VariablesDeclarations {if (ts_addr($1) == -1) { 
					  										ts_ajouter($1, flagConst, 0);
					  									  } else { 
					  									  	printf("ERREUR : Symbole déjà déclarée\n"); 
					  									  }}
					  | VAR tEGAL NOMBRE tVIRGULE VariablesDeclarations {if (ts_addr($1) == -1) { 
					  														ts_ajouter($1, flagConst, 1); 
					  														fprintf(fp, "AFC %d %d\n", ts_addr($1), $3);
					  														ligneAsmCourant++;
					  									  				} else { 
					  									  					printf("ERREUR : Symbole déjà déclarée\n"); 
					  									  				}}
					  ;


Instructions: Instruction  Instructions 
			| IfBloc Instructions
			|
			;

Instruction:  Affichage tFININSTRUCTION
			| Affectation tFININSTRUCTION
			|  error  tFININSTRUCTION	{ yyerrok; }
			;

Affichage : tECHO tPARO VAR tPARF     
			{
				if (ts_addr($3) == -1) { 
					printf("Erreur : variable non déclarée\n");
				} else {
					if (!est_initialise($3)) {
						printf("# Warning : variable non initialisée\n");
					}
					fprintf(fp, "PRI %d\n", ts_addr($3));
					ligneAsmCourant++;
				}
			}
			;

Affectation:		VAR tEGAL Expression		{ if(ts_addr($1) != -1) { 
								if (!est_constant($1) || ((est_constant($1)) && (!est_initialise($1)))) {
									ts_affect($1); 
									fprintf(fp, "COP %d %d \n", ts_addr($1), $3);
									ligneAsmCourant++;
									ts_depiler();
									nbVarTmpCourant--;
							        }
								else {
									printf(" \n# Constante initialisée détectée, modification impossible \n ")  ; 	
								}
							  }
							  else {
								printf(" \n# Variable non définie \n")  ;
							  }							
                                                        }
                    ;


Expression:
			NOMBRE				{ 
								  sprintf(nomVarTmpCourant, "var_tmp%d", nbVarTmpCourant);
								  ts_ajouter(nomVarTmpCourant, 1, 0); 
								  nbVarTmpCourant++;
								  fprintf(fp, "AFC %d %d\n", ts_addr(nomVarTmpCourant), $1);
								  ligneAsmCourant++;
								  $$=ts_addr(nomVarTmpCourant) ; 
								}
            | VAR               {if (ts_addr($1) == -1) {
									printf("Erreur : variable non déclarée\n");		
								} else if (est_initialise($1) == 0) {
									printf("Erreur : variable non initialisée\n");	
								} else { 
                                 	printf("# Stocker var dans var temporaire\n");
                                 	sprintf(nomVarTmpCourant, "var_tmp%d", nbVarTmpCourant);
								    ts_ajouter(nomVarTmpCourant, 1, 0); 
								    nbVarTmpCourant++;
								    fprintf(fp, "COP %d %d\n", ts_addr(nomVarTmpCourant), ts_addr($1)); 
								    ligneAsmCourant++;
							     	$$=ts_addr(nomVarTmpCourant) ;
                             	}}
			| tPARO Expression tPARF	{ $$=$2 ; } 
			| Expression tPLUS Expression 	{ 
												fprintf(fp, "ADD %d %d %d\n", $1, $1, $3) ; 
												ligneAsmCourant++;
											  	ts_depiler(); 
											  	nbVarTmpCourant--; 
											  	$$ = $1;
											}  
			| Expression tMOINS Expression	{ 
												fprintf(fp, "SUB %d %d %d\n", $1, $1, $3) ; 
												ligneAsmCourant++;
											  	ts_depiler(); 
											  	nbVarTmpCourant--; 
											  	$$ = $1;
										     } 
			| Expression tFOIS Expression	{ 
												fprintf(fp, "MUL %d %d %d\n", $1, $1, $3) ; 
												ligneAsmCourant++;
											  	ts_depiler(); 
											  	nbVarTmpCourant--; 
											  	$$ = $1;
											}
			| Expression tDIVISE Expression	{ 
												fprintf(fp, "DIV %d %d %d\n", $1, $1, $3) ; 
												ligneAsmCourant++;
											  	ts_depiler(); 
											  	nbVarTmpCourant--; 
											  	$$ = $1;
											 }
			| tMOINS Expression		{ printf("# Faire la négation d'une expression\n");
									  fprintf(fp, "SOU %d %d %d\n", $2, ts_addr(NOM_VAR_ZERO), $2);
									  ligneAsmCourant++;
									  $$ = $2; 
									}   %prec tFOIS
			; 


IfBloc: tIF tPARO Expression 
		{ 
		  	fprintf(fp, "JMF %d %s\n", ts_addr(nomVarTmpCourant), MARQUEUR_TIC);
		  	// depiler la var tmp cree par Expression
		  	ts_depiler();
			nbVarTmpCourant--;

		  	// empiler dans la table tic
		  	tic_ajouter_s(ligneAsmCourant);
		  	ligneAsmCourant++;

	    }
	    tPARF tACCO Instructions tACCF 
	    {
	    	tic_set_dest(ligneAsmCourant);
	    	printf ("Fin du truc if \n") ;
		}
	    ; 

Fin:			tACCF		{ printf ("Fin du programme \n") ; }  


%%

int yyerror(char *s) {
  printf("%s\n",s);
}

void remplacerMarqueursTIC(FILE* fileAsm) {
	char* line = NULL;
	char* ptr = NULL;
	char possibleMarqueur[strlen(MARQUEUR_TIC)];
	char c;
	int lineNum = 1;
	int read;
	size_t len;
	char oneword[WORD_CAPACITY];
	int arg1;

	FILE* fp2 = fopen("o2.asm", "w");
	// read all line
	
	while((read = getline(&line, &len, fileAsm)) != -1) {
		printf("%d : %s", lineNum, line);
		ptr = line;
		// read each word of line
		do {
	      	c = sscanf(ptr,"%s %d %s",oneword, &arg1, possibleMarqueur);   //got one word from the file 
	      	if (!strcmp(possibleMarqueur, MARQUEUR_TIC)) {
	      		printf("Yahooo on line %d, to replace by %d\n", lineNum, tic_get_dest(lineNum));
	      	}
		 	ptr = strstr(ptr, oneword);     // Find where the current word starts.
    		ptr += strlen(oneword);         // Skip past the current word.

    		// erase possibleMarqueur
    		strcpy(possibleMarqueur, "000");
	   } while (c == 0 && c != EOF);                  // repeat until EOF        
		lineNum++;
	}

	//fclose(fp1);
	fclose(fp2);
	if (line) {
      free(line);
  	}
}

int main(void) {
  // initialiser tab symboles 
  ts_init() ; 

  // initaliser tab IC
  tic_init();
  
  // open file on mode readwrite
  fp = fopen("o.asm","r+");
  fprintf(fp, "AFC %d 0\n", ts_addr(NOM_VAR_ZERO));
  ligneAsmCourant++;
  // parser
  yyparse();

 // affichage table des symboles 
  ts_print() ; 
  printf("Nb var temporaires : %d\n", nbVarTmpCourant);
  printf("Nb lignes asm : %d\n", ligneAsmCourant);

  
  // prepare fp to be read by remplacerMarqueursTIC
  rewind(fp);
  remplacerMarqueursTIC(fp);

  fclose(fp);
  // affichage table TIC
  tic_print();
  return 0;
}
