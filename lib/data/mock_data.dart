import '../models/activity.dart';

const bistro = Activity(
  category: 'Comida',
  name: 'Bistro',
  distance: '500 m',
  duration: '20–30 min',
  price: '\$12K',
  people: '1+ persona',
  imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=1000&q=80',
);

const pokeAndDraw = Activity(
  category: 'Manualidades',
  name: 'Poke & Dibujo',
  distance: '0.8 km',
  duration: '20–40 min',
  price: '\$15K',
  people: '2+',
  imageUrl: 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?auto=format&fit=crop&w=1000&q=80',
);

const recommendedActivities = [bistro, pokeAndDraw];

const nearbyActivities = [
  Activity(
    category: 'Manualidades',
    name: 'Dibujo y Más',
    distance: '0.8 km',
    duration: '60 min',
    price: '\$50K',
    people: '1 persona mínimo',
    imageUrl: '',
  ),
  Activity(
    category: 'Arte',
    name: 'Pintor Arte',
    distance: '1.2 km',
    duration: '45 min',
    price: '\$20K',
    people: '1 persona mínimo',
    imageUrl: '',
  ),
  Activity(
    category: 'Descanso',
    name: 'Tumbarse en el parque',
    distance: '0.4 km',
    duration: '∞',
    price: '\$0',
    people: '1 persona mínimo',
    imageUrl: '',
  ),
];

const friends = [
  FriendStatus(initials: 'DD', name: 'Daniel Duplet', status: 'Libre'),
  FriendStatus(initials: 'MD', name: 'María Díaz', status: 'Libre'),
  FriendStatus(initials: 'RC', name: 'Ricardo Condo', status: 'Libre'),
  FriendStatus(initials: 'LD', name: 'Lucía Delgado', status: 'Libre en 30 min', statusInMinutes: true),
  FriendStatus(initials: 'YR', name: 'Youcar Ruiz', status: 'Libre'),
];
