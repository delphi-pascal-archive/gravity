unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, ImgList, Math;

const
     MUR = $004080A0;                // definition des couleurs
     AIR = $0080C0E0;
     VAISSEAU = $00999999;
     
type
  TPointReal = record
             x,y:real;
             end;
  TJoueur = record
          pos:tpoint;  // position réelle
          Rpos:TPointReal; // position relative par rapport au bord de l'ecran
          vecteur:tpoint;     // vecteur de deplacement
          vecteurinertie:TPointREal; // vecteur d'inertie
          angle:integer; // angle du joueur
          puissance,PuissanceImpulsion:real; // puissance accumulée du moteur
          moteur:boolean; // moteur en route ou pas
          touche:integer; // touche frappée
          IndexTir:integer; // nombre de tir
          end;
  TTir = record
       pos:tpoint;  // position réelle
       posR:TpointReal;  // position relative par rapport au bord de l'ecran
       Delta:TpointReal;
       Actif:boolean;   // tir actif ou pas
       angle:integer;
       Explosion:integer;   // explosion ou pas
       end;
  TForm1 = class(TForm)
    ImgVaisseau: TImageList;  // contient les differentes images du vaisseau
    Aire: TPaintBox;
    Button2: TButton;
    pbVecteur: TPaintBox;
    Vue: TPaintBox;
    imgExplosion: TImageList;
    Timer1: TTimer;
    GroupBox1: TGroupBox;
    Button1: TButton;
    Button3: TButton;
    Edit1: TEdit;
    Edit3: TEdit;
    Fond: TImage;
    Function DessinerVaisseau(pos:tpoint;angle:integer;Dessiner:boolean):boolean;
    procedure Button1Click(Sender: TObject);
    procedure Init;
    procedure Button2Click(Sender: TObject);
    procedure LireLesTouchesEnAttente;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure MajVecteur(dessiner:boolean);
    procedure DessinerFond;
    procedure DessinerVue;
    function VerifierImpact:boolean;
    procedure explosion(pos:tpoint);
    procedure AjouterTir(StartPos:Tpoint);
    procedure GererTir;
    procedure DessinerTir(index:integer;Dessiner:boolean);
    procedure Button3Click(Sender: TObject);
    procedure UneExplosion(pos:tpoint;index:integer);
    procedure Timer1Timer(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
    Joueur:Tjoueur;
    Touche:integer;
    Stop:boolean;
    AirePos:tpoint;
    Tir:array[1..30] of Ttir;
  end;

var
  Form1: TForm1;
  Function StartHook                      :Boolean; stdcall; external 'DllHook.dll';   // gere l'appuie sur
  Function StopHook                       :Boolean; stdcall; external 'DllHook.dll';
  Function GetNextKey(Var Key,ID:Integer) :Boolean; stdcall; external 'DllHook.dll';   // les touches

implementation

{$R *.DFM}

procedure Tform1.Init;
var
   i:integer;
begin
for i:=1 to 30 do
    begin
    Tir[i].pos.x:=0;
    Tir[i].pos.y:=0;
    Tir[i].posR.x:=0;          // mie à Z des tirs
    Tir[i].posR.y:=0;
    Tir[i].Delta.x:=0;
    Tir[i].Delta.y:=0;
    Tir[i].Actif:=false;
    Tir[i].angle:=0;
    Tir[i].Explosion:=-1;
    end;
with Aire.canvas do
     begin
     pen.Color:=clblack;
     brush.color:=clblack;                   // efface l'aire de dessin
     rectangle(0,0,Aire.width,Aire.height);
     end;
with pbVecteur.canvas do
     begin
     pen.Color:=clBlack;
     brush.color:=clBlack;
     rectangle(0,0,PbVecteur.width,PbVecteur.height);    // efface l'affichage du vecteur
     pen.Color:=clLime;
     brush.color:=clBlack;
     ellipse(0,0,PbVecteur.width,PbVecteur.height);
     end;
Joueur.pos:=point(300,300);
Joueur.Rpos.X:=300;
Joueur.Rpos.Y:=300;
Joueur.vecteur:=point(0,0);
Joueur.angle:=0;                  // mise à Z des param du joueur
Joueur.puissance:=1;
Joueur.vecteurinertie.x:=0;
Joueur.vecteurinertie.y:=0;
Joueur.IndexTir:=0;
AirePos:=point(1,1);
DessinerFond;   // dessine le fond
end;

Function TForm1.DessinerVaisseau(pos:tpoint;angle:integer;Dessiner:boolean):boolean;
var
   Srect,Drect:trect;
   x,y:real;
begin
DRect:=rect(pos.x,pos.y,pos.x+60,pos.y+60);
pos.x:=pos.x-Airepos.x;        // definition de la position du joueur dans l'aire de dessin
Pos.y:=pos.y-Airepos.Y;
if dessiner=true then     // si on dessine le joueur
   begin
   //imgVaisseau.DrawingStyle:=
   imgVaisseau.Draw(Aire.canvas,pos.x,pos.y,floor(angle/15));  // dessine le vaisseau en fonction de l'angle
   if joueur.moteur=true then     // si le moteur est allumé
      begin
      y:=30+cos(Joueur.angle/360*2*PI)*16;   // on calcule la poussée donée par le moteur
      x:=30-sin(Joueur.angle/360*2*PI)*16;
      with aire.canvas do
        begin
        pen.color:=clred;         // et on dessine le feu du moteur
        brush.color:=clred;
        rectangle(floor(pos.x+x-2),floor(pos.y+y-2),floor(pos.x+x+2),floor(pos.y+y+2));
        end;
      end;
   end
else     // si on efface le joueur
    begin
    Srect:=rect(pos.x,pos.y,pos.x+60,pos.y+60);  // on copie la zone vierge du fond
    Aire.canvas.CopyRect(Srect,Fond.canvas,DRect); // sur l'aire de dessin
    //Aire.Canvas.Rectangle(pos.x,pos.y,pos.x+60,pos.y+60);
    end;
if dessiner=true then
   result:=VerifierImpact    // si on dessine le joueur alors il faut verifier si il y a impact
else
    result:=false;
end;

function TForm1.VerifierImpact:boolean;
var
   x,y:integer;
   Image1:tbitmap;
   oRect:Trect;
begin
image1:=Tbitmap.Create;   // mise en cache du dessin actuel du vaisseau
Image1.width:=60;
Image1.height:=60;
oRect := Rect(0,0, Image1.Width, Image1.Height);
 Image1.canvas.brush.Color:=clblack;
 Image1.Canvas.FillRect(oRect);
//imgVaisseau.GetBitmap(floor(Joueur.angle/15),Image1);
imgvaisseau.Draw(Image1.canvas,0,0,floor(Joueur.angle/15),true);

//application.processmessages;
for x:=1 to 60 do   // pour chaque pixel du vaisseau
    for y:=1 to 60 do
        begin
        if Fond.Canvas.Pixels[x+Joueur.pos.x,y+Joueur.pos.y]=MUR then  // si on est sur un mur
           begin
           if Image1.Canvas.Pixels[x,y]=VAISSEAU then     // et que c'est le vaisseau
              begin
              result:=true;            // alors le vaisseau touche le mur
              edit3.text:='Touche';   // on est mort
              exit;
              end
           else
               begin

               Edit3.text:='Sauf';
               end;
           end;
//        application.processmessages;
        end;
result:=false;
//image1.free;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
   x,x2,y:integer;
begin
for x:=0 to 23 do
    begin
    y:=40;
    x2:=x*50;
    if x>10 then
       begin
       y:=100;
       x2:=x*50-(550);
       end;
    if x>20 then
       begin
       y:=160;
       x2:=x*50-(1050);
       end;

    DessinerVaisseau(point(x2,y),x*15,true);
    end;
end;

procedure TForm1.Button2Click(Sender: TObject);   // moteur principal du jeu
var
   x,y:real;
begin
init;               // debut initialisation
stop:=false;
x:=0;
y:=0;
Joueur.touche:=0;
dessinerFOnd;       // Fin initialisation
while stop=false do
      begin
      LireLesTouchesEnAttente;   // on lit les touches frappées depuis la derniere boucle
      MajVecteur(false);  // maj affichage vecteur de poussée
      DessinerVaisseau(joueur.pos,Joueur.angle,false); // effacer vaisseau
      case joueur.touche of
           25:dec(Joueur.angle,15);  // selon touche changer angle du vaisseau
           27:inc(Joueur.angle,15);
           26:begin
              if timer1.enabled=false then
                 begin
                 AjouterTir(Joueur.pos);
                 timer1.enabled:=true;
                 end;
              end;
           end;
      if joueur.angle=-15 then Joueur.angle:=345;    // correction de l'angle
      if joueur.angle=360 then Joueur.angle:=0;     // si <0 ou >360
      GererTir;
      if Joueur.moteur=true then // si les moteurs sont en route
         begin
         Joueur.puissance:=Joueur.puissance+0.5; // la puissance augmente
         y:=cos(Joueur.angle/360*2*PI)*Joueur.puissance; // calcul de la force selon X et y
         x:=sin(Joueur.angle/360*2*PI)*Joueur.puissance; // donné par cette puissance = impulsion
         Joueur.vecteurinertie.x:=Joueur.vecteurinertie.x+x; // ajout de l'impulsion
         Joueur.vecteurinertie.y:=Joueur.vecteurinertie.y-y; // au vecteur de deplacement du vaisseau
         Joueur.Rpos.X:=Joueur.Rpos.X+Joueur.vecteurinertie.x; // puis deplacement
         Joueur.Rpos.Y:=Joueur.Rpos.Y+Joueur.vecteurinertie.y;  //                du
         Joueur.pos:=point(floor(Joueur.Rpos.X),floor(Joueur.Rpos.Y)); //            vaisseau
         end
      else
          begin     // si les moteurs ne sont PAS en route
          Joueur.puissance:=Joueur.puissance-1;   // la puissance diminue
          Joueur.Rpos.X:=Joueur.Rpos.X+Joueur.vecteurinertie.x; // on deplace le vaisseau
          Joueur.Rpos.Y:=Joueur.Rpos.Y+Joueur.vecteurinertie.y; // selon son vecteur de dpl
          Joueur.pos:=point(floor(Joueur.Rpos.X),floor(Joueur.Rpos.Y));
          end;
      Joueur.vecteurinertie.y:=Joueur.vecteurinertie.y+0.2; // l'inertie verticale est augmentée
                                                            // pour simuler la gravité
      if Joueur.puissance<0 then Joueur.puissance:=0;   // correction de la puissance
      if Joueur.puissance>1 then Joueur.puissance:=1;
      DessinerFond; // redessine le fond en fonction place du joueur
      if DessinerVaisseau(joueur.pos,Joueur.angle,true)=true then   // si impact du joueur contre mur
         begin
         explosion(Joueur.pos);
         exit;
         end;
      MajVecteur(true);   // maj du dessin du vecteur
      //edit1.text:=format('%d %d',[Joueur.pos.X,Joueur.pos.y]);
      application.processmessages;
      sleep(50);
      end;
end;

procedure Tform1.MajVecteur(dessiner:boolean);   // dessine un trait partant du centre du cercle
var                                           // en fonction de l'angle de poussée du vaisseau
   x,y:real;                                  // dans la paintbox vecteur
   Impulsion:Tpointreal;
begin
y:=cos(Joueur.angle/360*2*PI);
x:=sin(Joueur.angle/360*2*PI);
Impulsion.x:=sin(Joueur.vecteurinertie.x/360*2*PI);
Impulsion.y:=sin(Joueur.vecteurinertie.y/360*2*PI);
with pbVecteur.canvas do
     begin
     pen.Color:=clLime;
     brush.color:=clBlack;
     brush.style:=bsclear;
     ellipse(0,0,PbVecteur.width,PbVecteur.height);
     brush.Style:=bssolid;
     if dessiner=true then
        begin
        Pen.color:=clred;
        brush.color:=clred;
        end
     else
         begin
         Pen.color:=clblack;
         brush.color:=clblack;
         end;
     moveto(75,75);
     lineto(floor(75+x*75),floor(75-y*75));
     if dessiner=true then
        begin
        Pen.color:=cllime;
        brush.color:=cllime;
        end
     else
         begin
         Pen.color:=clblack;
         brush.color:=clblack;
         end;
     moveto(75,75);
     lineto(floor(75+Joueur.vecteurinertie.x*75),floor(75+Joueur.vecteurinertie.y*75));
     end;
//Edit2.text:=format('%.2f %.2f',[x,y]);
end;

procedure Tform1.LireLesTouchesEnAttente;
var
   key,id:integer;
begin
if stop=true then exit;
//TimerHook.enabled:=false;
while getnextkey(key,id) do  // lire la prochaine touche en attente
      begin
      if inttohex(key,8)='00000010' then //shift appuyé
            Joueur.moteur:=true;    // donc on allume le moteur
      if inttohex(key,8)='80000010' then  // sinon on l'éteind
         begin
         //elan:=floor((TabPuissance[0]/15)*sin(Joueur.angle*2*PI/360));
         Joueur.moteur:=false;
         end;
      if inttohex(Key,8)='0000001B' then Stop:=true;
      if inttohex(Key,8)='00000027' then Joueur.touche:=27;  //fleche droite
      if inttohex(Key,8)='00000044' then Joueur.touche:=27;  //touche D
      if inttohex(Key,8)='00000025' then Joueur.touche:=25;  //fleche gauche
      if inttohex(Key,8)='00000051' then Joueur.touche:=25;  //touche Q
      if inttohex(Key,8)='00000026' then Joueur.touche:=26;  // fleche haut
      if inttohex(Key,8)='0000005A' then Joueur.touche:=26;  // touche Z
      if inttohex(Key,8)='80000027' then Joueur.touche:=0;  //fleche droite  relachée
      if inttohex(Key,8)='80000044' then Joueur.touche:=0;  //touche D relachée
      if inttohex(Key,8)='80000025' then Joueur.touche:=0;  //fleche gauche relachée
      if inttohex(Key,8)='80000051' then Joueur.touche:=0;  //touche Q realchée
      if inttohex(Key,8)='80000026' then Joueur.touche:=0;  //fleche haut relachée
      if inttohex(Key,8)='8000005A' then Joueur.touche:=0;  // touche Z  relachée
      Edit1.text:=inttohex(key,8);
      end;

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
//imgVaisseau.BkColor:=clnone;
//imgexplosion.BkColor:=clnone;
//imgexplosion.DrawingStyle:=dstransparent;
fond.Picture.LoadFromFile('.\bitmap\Fond.bmp');  // chargement du niveau
stop:=true;
StartHook;   // mise en route du Hook clavier
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
stop:=true;   // forcer la fin de la boucle moteur en cas de sortie sans mort
stophook;  // arret hook clavier
end;

procedure TForm1.DessinerFond;  // dessine le fond dans l'aire de jeu
var                             // focalisé sur la zone visible
   Srect,Drect:trect;
   bool,bool2:boolean;
begin
//Joueur.pos.y-(floor(Joueur.pos.y/600)*600)>550 then
//Edit2.text:=format('%d',[Joueur.pos.y-(floor(Joueur.pos.y/600)*600)]);
//Bool2:=Joueur.pos.x-(floor(Joueur.pos.x/600)*600)>550;
Srect.top:=floor(Joueur.pos.y/600)*600;  // chargement du fond du niveau
Srect.Left:=floor(Joueur.pos.x/600)*600;   //  correspondant à l'endroit
Srect.Right:=Srect.Left+600;               // ou se trouve le joueur
Srect.Bottom:=Srect.Top+600;              // en memoire
if (Srect.top<>Airepos.y) or
   (Srect.Left<>AirePos.x) then
   begin
   Drect:=Rect(0,0,600,600);   // destination aire de jeu
   with Aire.canvas do
     begin
     copyrect(Drect,Fond.canvas,Srect);  // copie de la zone dans l'aire de jeux
     end;
   AirePos.x:=Srect.Left;   // mise à jour des coordonnées de l'aire de jeux
   AirePos.y:=Srect.Top;
   DessinerVue;       // dessiner l'aire de jeu
   end;
AirePos.x:=Srect.Left;
AirePos.y:=Srect.Top;
//Edit1.text:=format('%d %d',[Airepos.x,Airepos.y]);
end;

procedure Tform1.DessinerVue; // dessine le fond du niveau complet dans l'aperçu
var
   coord:trect;
begin
coord:=rect(0,0,Vue.width,vue.height);
with vue.canvas do
     begin
     StretchDraw(coord,FOnd.Picture.Bitmap);
     pen.color:=clred;
     brush.style:=bsclear;
     rectangle(floor(Airepos.x/10),floor(AIrepos.y/10),floor(Airepos.x/10+60),floor(airepos.y/10+60));
     end;

end;

procedure TForm1.explosion(pos:Tpoint);  // dessine l'explosion du vaisseau
var
   i:integer;
   Srect,Drect:trect;
begin
Drect:=rect(pos.x-Airepos.x,pos.y-Airepos.y,pos.x-Airepos.x+60,pos.y-Airepos.y+60);
Srect:=rect(pos.x,pos.y,pos.x+60,pos.y+60);
for i:=0 to 19 do   // l'explosion est découpée en 20 images
    begin
    with Aire.canvas do
         begin
         Copyrect(Drect,fond.canvas,Srect);
         end;
    imgExplosion.draw(Aire.canvas,pos.x-Airepos.x,pos.y-AIrepos.y,i,true);// que l'on dessine  successivement
    sleep(50);                                                             // ou se trouve le joueur
    end;
end;

procedure Tform1.UneExplosion(pos:tpoint;index:integer);  //charge une des 20 images de l'explosion
var                                                       // du joueur
   Srect,Drect:trect;
begin
Drect:=rect(pos.x-Airepos.x,pos.y-Airepos.y,pos.x-Airepos.x+60,pos.y-Airepos.y+60);
Srect:=rect(pos.x,pos.y,pos.x+60,pos.y+60);
with Aire.canvas do
     begin
     Copyrect(Drect,fond.canvas,Srect);   // lire en mémoire l'image concernée
     end;
imgExplosion.draw(Aire.canvas,pos.x-Airepos.x,pos.y-AIrepos.y,index,true); // dessiner
end;

procedure Tform1.AjouterTir(StartPos:Tpoint);  // rajouter un tir dans la liste
var
   i:integer;
   bool:boolean;
begin
i:=1;
bool:=false;
while (i<30) and (bool=false) do   // faire le tour des 30 tirs possibles
      begin
      if Tir[i].Actif=false  // pour un trouver qui n'est pas utilisé
         then bool:=true
      else
          inc(i);
      end;
if bool=true then     // on a trouvé un tir non utilisé
   begin              // alors on le met en route
   Tir[i].posR.x:=Startpos.x;
   Tir[i].posR.y:=Startpos.y;      // en notant sa position
   Tir[i].Delta.x:=sin(Joueur.angle/360*2*PI);   // et sa direction
   Tir[i].Delta.y:=cos(Joueur.angle/360*2*PI);
   Tir[i].pos.x:=floor(Startpos.x);  // et son point de départ
   Tir[i].pos.y:=floor(Startpos.y);
   Tir[i].angle:=Joueur.angle;    // et son angle
   Tir[i].Actif:=true;         // on le défini comme actif
   end;
end;

procedure TForm1.GererTir;  //gestion du déplacement des tirs
var
   i:integer;
begin
for i:=1 to 30 do
    begin
    if (tir[i].Actif=true) and (tir[i].Explosion=-1) then // pour chaque tir actif
       begin                                              // et pas en train d'exploser
       DessinerTir(i,false);     // on efface le tir de son ancienne position
       Tir[i].posR.x:=Tir[i].posR.x+10*Tir[i].Delta.x;   // on le deplace selon x et y
       Tir[i].posR.y:=Tir[i].posR.y-10*Tir[i].Delta.y;
       Tir[i].pos.x:=floor(Tir[i].posR.x);
       Tir[i].pos.y:=floor(Tir[i].posR.y);
       DessinerTir(i,true);      // et on dessine sa nouvelle position
       end;
    if tir[i].Explosion<>-1 then  // si le tir explose
       begin
       UneExplosion(tir[i].pos,Tir[i].explosion); // on dessine son explosion en cours
       inc(tir[i].explosion); // au prochain passage on dessine l'image d'explosion suivante
       if tir[i].Explosion>19 then // si on a affiché toute les images
          begin
          tir[i].Actif:=false;       // on desactive ce tir
          tir[i].Explosion:=-1;
          end;
       end;
    end;
end;

procedure TForm1.DessinerTir(index:integer;dessiner:boolean);
var
   pos:tpoint;
begin
pos.x:=floor(Tir[index].Pos.x+30+sin(Tir[index].angle/360*2*PI)*16);  // calcul de la pos réélle du tir
pos.y:=floor(Tir[index].Pos.y+30-cos(Tir[index].angle/360*2*PI)*16);
if Fond.Canvas.Pixels[pos.x,pos.y]=MUR then  // si le tir touche le décor
   begin
   //explosion(point(pos.x-30,pos.y-30));
   //tir[index].Actif:=false;
   tir[index].Explosion:=0;     // il est terminé
   dessiner:=false;
   end;
pos.x:=Pos.x-AirePOs.x;
pos.y:=Pos.y-AirePOs.y;
with Aire.canvas do
     begin
     brush.style:=bssolid;
     if dessiner=true then  // si on dessine c'est du rouge
        begin
        pen.color:=clred;
        brush.color:=clred;
        end
     else       // si on efface c'est couleur AIR
         begin
         pen.color:=AIR;
         brush.color:=AIr;
         end;
     rectangle(Pos.x-2,Pos.y-2,Pos.x+2,Pos.y+2);  // on dessine
     end;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
 fond.Picture.LoadFromFile('.\bitmap\Fond.bmp');
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
 timer1.Enabled:=false;
end;

end.
